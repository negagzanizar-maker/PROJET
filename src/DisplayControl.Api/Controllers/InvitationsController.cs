using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.Json;

using DisplayControl.Api.Security;
using DisplayControl.Application.Security;
using DisplayControl.Domain.Identity;
using DisplayControl.Infrastructure.Identity;
using DisplayControl.Infrastructure.Persistence;
using DisplayControl.Infrastructure.Tenancy;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DisplayControl.Api.Controllers;

[ApiController]
public sealed class InvitationsController(
    DisplayControlDbContext dbContext,
    UserManager<ApplicationUser> userManager,
    ScopedTenantContext tenantContext,
    ITenantCapabilityTokenService capabilityTokenService,
    ISensitivePayloadProtector payloadProtector,
    TimeProvider timeProvider) : ControllerBase
{
    [HttpPost("api/v1/tenants/{tenantId:guid}/invitations")]
    [Authorize(Policy = AuthorizationPolicies.TenantAdministrator)]
    [ProducesResponseType<InvitationCreatedResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<InvitationCreatedResponse>> Create(
        Guid tenantId,
        CreateInvitationRequest request,
        CancellationToken cancellationToken)
    {
        var creatorId = ParseCurrentUserId();
        var normalizedEmail = userManager.NormalizeEmail(request.Email.Trim());
        if (string.IsNullOrWhiteSpace(normalizedEmail))
        {
            return BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]>
            {
                ["email"] = ["A valid email address is required."]
            })
            {
                Type = "https://docs.example.invalid/problems/validation",
                Title = "The request could not be accepted.",
                Status = StatusCodes.Status400BadRequest,
                Extensions = { ["code"] = "validation_failed" }
            });
        }

        var nowUtc = timeProvider.GetUtcNow();
        var expiresAtUtc = nowUtc.AddHours(24);
        var capability = capabilityTokenService.Generate(tenantId);
        var invitation = new Invitation(
            Guid.NewGuid(),
            tenantId,
            normalizedEmail,
            request.Role,
            capability.Digest,
            expiresAtUtc,
            creatorId,
            nowUtc);
        dbContext.Invitations.Add(invitation);
        var notificationPayload = JsonSerializer.Serialize(new InvitationNotificationPayload(capability.Value));
        dbContext.IdentityNotifications.Add(new IdentityNotification(
            Guid.NewGuid(),
            null,
            tenantId,
            "InvitationCreated",
            normalizedEmail,
            payloadProtector.ProtectionScheme,
            payloadProtector.Protect(notificationPayload),
            nowUtc));

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (
            exception.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            return ConflictProblem("pending_invitation_exists", "A pending invitation already exists for this email.");
        }

        return Created(
            $"/api/v1/tenants/{tenantId}/invitations/{invitation.Id}",
            new InvitationCreatedResponse(
                invitation.Id,
                request.Email.Trim(),
                request.Role,
                expiresAtUtc,
                capability.Value));
    }

    [HttpPost("api/v1/invitations/{token}/accept")]
    [AllowAnonymous]
    [EnableRateLimiting("authentication")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Accept(
        string token,
        AcceptInvitationRequest request,
        CancellationToken cancellationToken)
    {
        if (!capabilityTokenService.TryReadTenantId(token, out var tenantId))
        {
            return InvalidInvitation();
        }

        tenantContext.SetForCapabilityLookup(tenantId);
        await using var transaction = await dbContext.BeginTenantTransactionAsync(tenantId, cancellationToken);
        var tokenDigest = capabilityTokenService.ComputeDigest(token);
        var invitation = await dbContext.Invitations.SingleOrDefaultAsync(
            value => value.TokenDigest == tokenDigest,
            cancellationToken);
        var nowUtc = timeProvider.GetUtcNow();
        if (invitation is null || !invitation.CanBeConsumedAt(nowUtc))
        {
            return InvalidInvitation();
        }

        var existingUser = await userManager.FindByEmailAsync(invitation.NormalizedEmail);
        if (existingUser is not null)
        {
            return ConflictProblem(
                "account_exists_sign_in_required",
                "An account already exists for this invitation. Sign in to continue.");
        }

        var user = new ApplicationUser
        {
            Id = Guid.NewGuid(),
            UserName = invitation.NormalizedEmail,
            Email = invitation.NormalizedEmail,
            EmailConfirmed = true,
            DisplayName = request.DisplayName.Trim(),
            AccountState = AccountState.Active,
            HomeTenantId = tenantId,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            ConcurrencyStamp = Guid.NewGuid().ToString("N"),
            CreatedAtUtc = nowUtc,
            UpdatedAtUtc = nowUtc,
            LastPasswordChangedAtUtc = nowUtc,
            LockoutEnabled = true
        };
        var creationResult = await userManager.CreateAsync(user, request.Password);
        if (!creationResult.Succeeded)
        {
            return IdentityValidationProblem(creationResult.Errors);
        }

        invitation.Consume(user.Id, invitation.NormalizedEmail, nowUtc);
        dbContext.TenantMemberships.Add(new TenantMembership(
            Guid.NewGuid(),
            tenantId,
            user.Id,
            invitation.IntendedRole,
            invitation.CreatedByUserId,
            nowUtc));
        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return NoContent();
    }

    private Guid ParseCurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(value, out var userId)
            ? userId
            : throw new InvalidOperationException("Authenticated principal has no valid user identifier.");
    }

    private static BadRequestObjectResult InvalidInvitation() => new(new ProblemDetails
    {
        Type = "https://docs.example.invalid/problems/invitation-invalid",
        Title = "The invitation is invalid, expired, or already used.",
        Status = StatusCodes.Status400BadRequest,
        Extensions = { ["code"] = "invitation_invalid" }
    });

    private static ObjectResult ConflictProblem(string code, string title) => new(new ProblemDetails
    {
        Type = "https://docs.example.invalid/problems/invitation-state",
        Title = title,
        Status = StatusCodes.Status409Conflict,
        Extensions = { ["code"] = code }
    })
    {
        StatusCode = StatusCodes.Status409Conflict
    };

    private static ObjectResult IdentityValidationProblem(IEnumerable<IdentityError> errors)
    {
        var safeErrors = errors.Select(error => error.Code switch
        {
            "PasswordTooShort" => "Password does not meet the minimum length.",
            "PasswordRequiresDigit" => "Password must contain a digit.",
            "PasswordRequiresLower" => "Password must contain a lowercase letter.",
            "PasswordRequiresUpper" => "Password must contain an uppercase letter.",
            "PasswordRequiresUniqueChars" => "Password must contain more unique characters.",
            _ => "Account details could not be accepted."
        }).Distinct(StringComparer.Ordinal).ToArray();
        return new ObjectResult(new ValidationProblemDetails(new Dictionary<string, string[]>
        {
            ["account"] = safeErrors
        })
        {
            Type = "https://docs.example.invalid/problems/validation",
            Title = "The request could not be accepted.",
            Status = StatusCodes.Status400BadRequest,
            Extensions = { ["code"] = "validation_failed" }
        })
        {
            StatusCode = StatusCodes.Status400BadRequest
        };
    }
}

public sealed record CreateInvitationRequest(
    [param: Required, EmailAddress, StringLength(320)] string Email,
    TenantRole Role);

public sealed record AcceptInvitationRequest(
    [param: Required, StringLength(160, MinimumLength = 1)] string DisplayName,
    [param: Required, StringLength(1024, MinimumLength = 12)] string Password);

public sealed record InvitationCreatedResponse(
    Guid Id,
    string Email,
    TenantRole Role,
    DateTimeOffset ExpiresAtUtc,
    string Token);

internal sealed record InvitationNotificationPayload(string Token);
