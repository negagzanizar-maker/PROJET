using System.Security.Cryptography;
using System.Text.Json;
using DisplayControl.Api.Controllers;
using DisplayControl.Api.Scheduling;
using DisplayControl.Api.Security;
using DisplayControl.Application.Security;
using DisplayControl.Domain.Devices;
using DisplayControl.Domain.Licensing;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DisplayControl.Api.Devices;

public enum DeviceHeartbeatOutcome
{
    Success,
    Invalid,
    Replay
}

public sealed record DeviceHeartbeatWorkflowResult(
    DeviceHeartbeatOutcome Outcome,
    DeviceHeartbeatResponse? Response = null);

public sealed class DeviceHeartbeatWorkflow(
    DisplayControlDbContext dbContext,
    ILicenseLeaseSigner leaseSigner,
    DesiredStateResolver desiredStateResolver,
    DeviceProtocolOptions protocolOptions,
    TimeProvider timeProvider)
{
    public async Task<DeviceHeartbeatWorkflowResult> ProcessAsync(
        Guid tenantId,
        Guid deviceId,
        Guid certificateId,
        string remoteIpAddress,
        Guid correlationId,
        DeviceHeartbeatRequest request,
        CancellationToken cancellationToken)
    {
        if (request.BootId == Guid.Empty ||
            !DeviceInventoryNormalizer.TryNormalize(request.NetworkInterfaces, out var normalizedInterfaces) ||
            request.ReportedSentAtUtc is { Offset: var reportedOffset } && reportedOffset != TimeSpan.Zero)
        {
            return new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Invalid);
        }

        var nowUtc = timeProvider.GetUtcNow();
        var requestSha256 = SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(request));
        var idempotencyLockKey = $"heartbeat:{deviceId:N}:{request.BootId:N}";
        await dbContext.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({idempotencyLockKey}, 0))",
            cancellationToken);
        var priorHeartbeat = await dbContext.DeviceHeartbeats.AsNoTracking().SingleOrDefaultAsync(
            value => value.DeviceId == deviceId && value.BootId == request.BootId && value.Sequence == request.Sequence,
            cancellationToken);
        if (priorHeartbeat is not null)
        {
            if (!CryptographicOperations.FixedTimeEquals(priorHeartbeat.RequestSha256, requestSha256) ||
                string.IsNullOrWhiteSpace(priorHeartbeat.ResponseJson))
            {
                return new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Replay);
            }

            var priorResponse = JsonSerializer.Deserialize<DeviceHeartbeatResponse>(priorHeartbeat.ResponseJson)
                ?? throw new InvalidOperationException("Stored heartbeat response is invalid.");
            return new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Success, priorResponse);
        }

        var latestSequence = await dbContext.DeviceHeartbeats
            .Where(value => value.DeviceId == deviceId && value.BootId == request.BootId)
            .MaxAsync(value => (long?)value.Sequence, cancellationToken) ?? 0;
        if (request.Sequence <= latestSequence)
        {
            return new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Replay);
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
            return new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Invalid);
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
        var heartbeatRecord = new DeviceHeartbeat(
            Guid.NewGuid(),
            tenantId,
            deviceId,
            request.BootId,
            request.Sequence,
            requestSha256,
            request.ReportedSentAtUtc,
            nowUtc,
            remoteIpAddress,
            inventoryJson,
            request.AppliedDesiredStateVersion,
            request.PlayerStateCode,
            request.FreeDiskBytes,
            request.LastErrorCode,
            correlationId);
        dbContext.DeviceHeartbeats.Add(heartbeatRecord);

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
        DeviceHeartbeatResponse response;
        if (license is null)
        {
            response = new DeviceHeartbeatResponse(
                nowUtc,
                30,
                "notLicensed",
                null,
                null,
                new DesiredStateSummaryResponse("notLicensed", null, null));
        }
        else
        {
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
            response = new DeviceHeartbeatResponse(
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
                    : new DesiredStateSummaryResponse("available", desiredState.Id, desiredState.Version));
        }

        heartbeatRecord.RecordResponse(JsonSerializer.Serialize(response));
        return await TrySaveAsync(cancellationToken)
            ? new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Success, response)
            : new DeviceHeartbeatWorkflowResult(DeviceHeartbeatOutcome.Replay);
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
}
