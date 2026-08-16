using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.Json;
using DisplayControl.Api.Scheduling;
using DisplayControl.Api.Security;
using DisplayControl.Application.Security;
using DisplayControl.Domain.Devices;
using DisplayControl.Domain.Licensing;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DisplayControl.Api.Controllers;

[ApiController]
[Route("device/v1/heartbeats")]
public sealed class DeviceHeartbeatsController(
    DisplayControlDbContext dbContext,
    ILicenseLeaseSigner leaseSigner,
    DesiredStateResolver desiredStateResolver,
    DeviceProtocolOptions protocolOptions,
    TimeProvider timeProvider) : ControllerBase
{
    [HttpPost]
    [Authorize(Policy = AuthorizationPolicies.DeviceAuthenticated)]
    [IgnoreAntiforgeryToken]
    [RequestSizeLimit(64 * 1024)]
    public async Task<ActionResult<DeviceHeartbeatResponse>> Heartbeat(
        DeviceHeartbeatRequest request,
        CancellationToken cancellationToken)
    {
        if (!DeviceInventoryNormalizer.TryNormalize(request.NetworkInterfaces, out var normalizedInterfaces) ||
            request.ReportedSentAtUtc is { Offset: var reportedOffset } && reportedOffset != TimeSpan.Zero)
        {
            return InvalidHeartbeat();
        }

        var tenantId = RequiredClaimGuid(DeviceClaimTypes.TenantId);
        var deviceId = RequiredClaimGuid(DeviceClaimTypes.DeviceId);
        var certificateId = RequiredClaimGuid(DeviceClaimTypes.CertificateId);
        var nowUtc = timeProvider.GetUtcNow();
        var latestSequence = await dbContext.DeviceHeartbeats
            .Where(value => value.DeviceId == deviceId)
            .MaxAsync(value => (long?)value.Sequence, cancellationToken) ?? 0;
        if (request.Sequence <= latestSequence)
        {
            return Conflict(new ProblemDetails
            {
                Type = "https://docs.example.invalid/problems/heartbeat-replay",
                Title = "The heartbeat sequence was already observed.",
                Status = StatusCodes.Status409Conflict,
                Extensions = { ["code"] = "heartbeat_replay" }
            });
        }

        var device = await dbContext.Devices.SingleAsync(value => value.Id == deviceId, cancellationToken);
        try
        {
            device.RecordHeartbeat(
                request.Hostname,
                request.OsDescription,
                request.Architecture,
                request.AgentVersion,
                request.PlayerVersion,
                request.DiskCapacityBytes,
                request.AppliedDesiredStateVersion,
                request.PlayerStateCode,
                nowUtc);
        }
        catch (ArgumentException)
        {
            return InvalidHeartbeat();
        }

        var inventoryJson = JsonSerializer.Serialize(new
        {
            request.Hostname,
            request.OsDescription,
            request.Architecture,
            request.AgentVersion,
            request.PlayerVersion,
            request.DiskCapacityBytes,
            networkInterfaces = normalizedInterfaces
        });
        dbContext.DeviceHeartbeats.Add(new DeviceHeartbeat(
            Guid.NewGuid(),
            tenantId,
            deviceId,
            request.Sequence,
            request.ReportedSentAtUtc,
            nowUtc,
            HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            inventoryJson,
            request.AppliedDesiredStateVersion,
            request.PlayerStateCode,
            request.FreeDiskBytes,
            request.LastErrorCode,
            HttpContext.TraceIdentifierGuid()));

        var existingInterfaces = await dbContext.DeviceNetworkInterfaces
            .Where(value => value.DeviceId == deviceId)
            .ToListAsync(cancellationToken);
        dbContext.DeviceNetworkInterfaces.RemoveRange(existingInterfaces);
        foreach (var network in normalizedInterfaces)
        {
            dbContext.DeviceNetworkInterfaces.Add(new DeviceNetworkInterface(
                Guid.NewGuid(),
                tenantId,
                deviceId,
                network.InterfaceName,
                network.MacAddress,
                JsonSerializer.Serialize(network.LocalAddresses),
                nowUtc));
        }

        var license = await dbContext.Licenses
            .Where(value => value.DeviceId == deviceId &&
                value.ControlState == LicenseControlState.Enabled &&
                value.ValidFromUtc <= nowUtc &&
                value.ExpiresAtUtc > nowUtc)
            .OrderBy(value => value.ExpiresAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (license is null)
        {
            if (!await TrySaveAsync(cancellationToken))
            {
                return HeartbeatReplay();
            }

            return Ok(new DeviceHeartbeatResponse(
                nowUtc,
                30,
                "notLicensed",
                null,
                null,
                new DesiredStateSummaryResponse("notLicensed", null, null)));
        }

        var desiredState = await desiredStateResolver.ResolveAsync(deviceId, nowUtc, cancellationToken);
        var certificate = await dbContext.DeviceCertificates.AsNoTracking().SingleAsync(
            value => value.Id == certificateId,
            cancellationToken);
        var authorizationBoundaryUtc = desiredState?.EndsAtUtc is DateTimeOffset scheduleEndUtc &&
            scheduleEndUtc < certificate.NotAfterUtc
                ? scheduleEndUtc
                : certificate.NotAfterUtc;
        var signedLease = leaseSigner.Issue(
            tenantId,
            deviceId,
            certificateId,
            license,
            nowUtc,
            protocolOptions.OfflineAllowance,
            desiredState?.Id,
            desiredState?.Version,
            desiredState?.ManifestSha256,
            authorizationBoundaryUtc);
        license.RecordLeaseIssued(signedLease.ExpiresAtUtc, nowUtc);
        if (!await TrySaveAsync(cancellationToken))
        {
            return HeartbeatReplay();
        }

        return Ok(new DeviceHeartbeatResponse(
            nowUtc,
            30,
            "licensed",
            new LicenseLeaseResponse(
                signedLease.Token,
                signedLease.KeyId,
                signedLease.ExpiresAtUtc,
                leaseSigner.VerificationKey.Algorithm,
                leaseSigner.VerificationKey.SubjectPublicKeyInfoPem),
            license.ExpiresAtUtc,
            desiredState is null
                ? new DesiredStateSummaryResponse("licensedNoContent", null, null)
                : new DesiredStateSummaryResponse("available", desiredState.Id, desiredState.Version)));
    }

    private async Task<bool> TrySaveAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateException exception) when (
            exception.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            return false;
        }
    }

    private Guid RequiredClaimGuid(string claimType) =>
        Guid.TryParse(User.FindFirstValue(claimType), out var value)
            ? value
            : throw new InvalidOperationException("The device principal is missing a required binding claim.");

    private static BadRequestObjectResult InvalidHeartbeat() => new(new ValidationProblemDetails(
        new Dictionary<string, string[]> { ["heartbeat"] = ["The heartbeat inventory or timestamp is invalid."] })
    {
        Type = "https://docs.example.invalid/problems/heartbeat-invalid",
        Title = "The heartbeat is invalid.",
        Status = StatusCodes.Status400BadRequest,
        Extensions = { ["code"] = "heartbeat_invalid" }
    });

    private static ConflictObjectResult HeartbeatReplay() => new(new ProblemDetails
    {
        Type = "https://docs.example.invalid/problems/heartbeat-replay",
        Title = "The heartbeat sequence was already observed.",
        Status = StatusCodes.Status409Conflict,
        Extensions = { ["code"] = "heartbeat_replay" }
    });
}

public sealed record DeviceHeartbeatRequest(
    [param: Range(1, long.MaxValue)] long Sequence,
    DateTimeOffset? ReportedSentAtUtc,
    [param: Required, StringLength(253, MinimumLength = 1)] string Hostname,
    [param: Required, StringLength(256, MinimumLength = 1)] string OsDescription,
    [param: Required, StringLength(32, MinimumLength = 1)] string Architecture,
    [param: Required, StringLength(64, MinimumLength = 1)] string AgentVersion,
    [param: Required, StringLength(64, MinimumLength = 1)] string PlayerVersion,
    [param: Range(1, long.MaxValue)] long DiskCapacityBytes,
    [param: Range(0, long.MaxValue)] long? FreeDiskBytes,
    long? AppliedDesiredStateVersion,
    [param: Required, StringLength(64, MinimumLength = 1)] string PlayerStateCode,
    [param: StringLength(64)] string? LastErrorCode,
    IReadOnlyList<DeviceEnrollmentNetworkRequest> NetworkInterfaces);

public sealed record DeviceHeartbeatResponse(
    DateTimeOffset ServerTimeUtc,
    int RetryAfterSeconds,
    string LicenseStatus,
    LicenseLeaseResponse? Lease,
    DateTimeOffset? LicenseExpiresAtUtc,
    DesiredStateSummaryResponse DesiredState);

public sealed record LicenseLeaseResponse(
    string Token,
    string KeyId,
    DateTimeOffset ExpiresAtUtc,
    string Algorithm,
    string SubjectPublicKeyInfoPem);

public sealed record DesiredStateSummaryResponse(string Status, Guid? Id, long? Version);
