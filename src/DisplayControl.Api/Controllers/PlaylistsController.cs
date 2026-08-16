using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.Json;

using DisplayControl.Api.Security;
using DisplayControl.Domain.Content;
using DisplayControl.Domain.Operations;
using DisplayControl.Domain.Playlists;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace DisplayControl.Api.Controllers;

[ApiController]
[Route("api/v1/tenants/{tenantId:guid}/playlists")]
public sealed class PlaylistsController(
    DisplayControlDbContext dbContext,
    TimeProvider timeProvider) : ControllerBase
{
    [HttpGet]
    [Authorize(Policy = AuthorizationPolicies.TenantViewer)]
    public async Task<ActionResult<IReadOnlyList<PlaylistResponse>>> List(
        Guid tenantId,
        [FromQuery, Range(1, 100)] int limit = 50,
        CancellationToken cancellationToken = default)
    {
        var playlists = await dbContext.Playlists.AsNoTracking()
            .OrderByDescending(value => value.UpdatedAtUtc)
            .Take(limit)
            .ToListAsync(cancellationToken);
        var ids = playlists.Select(value => value.Id).ToArray();
        var versions = await dbContext.PlaylistVersions.AsNoTracking()
            .Where(value => ids.Contains(value.PlaylistId))
            .OrderByDescending(value => value.VersionNumber)
            .ToListAsync(cancellationToken);
        var latest = versions.GroupBy(value => value.PlaylistId)
            .ToDictionary(group => group.Key, group => group.First());
        return Ok(playlists.Select(value => ToResponse(value, latest.GetValueOrDefault(value.Id), 0)).ToArray());
    }

    [HttpPost]
    [Authorize(Policy = AuthorizationPolicies.TenantContentManager)]
    public async Task<ActionResult<PlaylistResponse>> Create(
        Guid tenantId,
        CreatePlaylistRequest request,
        CancellationToken cancellationToken)
    {
        if (request.Items.Count is < 1 or > 100 ||
            request.Items.Select(value => value.ContentVersionId).Distinct().Count() != request.Items.Count)
        {
            return InvalidPlaylist("playlist_items_invalid", "A playlist requires 1–100 unique content versions.");
        }

        var versionIds = request.Items.Select(value => value.ContentVersionId).ToArray();
        var contentVersions = await dbContext.ContentVersions
            .Where(value => versionIds.Contains(value.Id))
            .ToListAsync(cancellationToken);
        var assetIds = contentVersions.Select(value => value.ContentAssetId).ToArray();
        var assets = await dbContext.ContentAssets
            .Where(value => assetIds.Contains(value.Id))
            .ToDictionaryAsync(value => value.Id, cancellationToken);
        if (contentVersions.Count != versionIds.Length ||
            contentVersions.Any(value => value.ApprovedAtUtc is null ||
                !string.Equals(value.ScanState, "clean", StringComparison.Ordinal) ||
                !assets.TryGetValue(value.ContentAssetId, out var asset) ||
                asset.LifecycleState != ContentLifecycleState.Approved))
        {
            return ConflictProblem("content_not_approved", "Every playlist item must reference approved clean content.");
        }

        var contentById = contentVersions.ToDictionary(value => value.Id);
        for (var index = 0; index < request.Items.Count; index++)
        {
            var item = request.Items[index];
            var mediaKind = assets[contentById[item.ContentVersionId].ContentAssetId].MediaKind;
            if ((mediaKind != MediaKind.Mp4 && item.DurationMilliseconds is null) ||
                item.DurationMilliseconds is < 1000 or > 86_400_000 ||
                (mediaKind != MediaKind.Mp4 && item.LoopVideo))
            {
                return InvalidPlaylist(
                    "playlist_presentation_invalid",
                    "Images and text require a 1-second to 24-hour duration; only videos can loop.");
            }
        }

        var actorId = CurrentUserId();
        var nowUtc = timeProvider.GetUtcNow();
        var playlist = new Playlist(
            Guid.NewGuid(),
            tenantId,
            request.Name,
            request.Description,
            actorId,
            nowUtc);
        var version = new PlaylistVersion(
            Guid.NewGuid(),
            tenantId,
            playlist.Id,
            1,
            playlist.Name,
            playlist.Description,
            actorId,
            nowUtc);
        dbContext.Playlists.Add(playlist);
        dbContext.PlaylistVersions.Add(version);
        dbContext.PlaylistItems.AddRange(request.Items.Select((item, position) => new PlaylistItem(
            Guid.NewGuid(),
            tenantId,
            version.Id,
            item.ContentVersionId,
            position,
            item.DurationMilliseconds,
            item.LoopVideo,
            "{}")));
        AddAudit(tenantId, actorId, "playlist.created", playlist.Id, new { versionId = version.Id }, nowUtc);
        await dbContext.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(Get), new { tenantId, playlistId = playlist.Id }, ToResponse(
            playlist,
            version,
            request.Items.Count));
    }

    [HttpGet("{playlistId:guid}")]
    [Authorize(Policy = AuthorizationPolicies.TenantViewer)]
    public async Task<ActionResult<PlaylistResponse>> Get(
        Guid tenantId,
        Guid playlistId,
        CancellationToken cancellationToken)
    {
        var playlist = await dbContext.Playlists.AsNoTracking().SingleOrDefaultAsync(
            value => value.Id == playlistId,
            cancellationToken);
        if (playlist is null)
        {
            return NotFound();
        }

        var version = await dbContext.PlaylistVersions.AsNoTracking()
            .Where(value => value.PlaylistId == playlistId)
            .OrderByDescending(value => value.VersionNumber)
            .FirstAsync(cancellationToken);
        var itemCount = await dbContext.PlaylistItems.CountAsync(
            value => value.PlaylistVersionId == version.Id,
            cancellationToken);
        return Ok(ToResponse(playlist, version, itemCount));
    }

    [HttpPost("{playlistId:guid}/versions/{versionId:guid}/publish")]
    [Authorize(Policy = AuthorizationPolicies.TenantContentManager)]
    public async Task<ActionResult<PlaylistResponse>> Publish(
        Guid tenantId,
        Guid playlistId,
        Guid versionId,
        CancellationToken cancellationToken)
    {
        var playlist = await dbContext.Playlists.SingleOrDefaultAsync(
            value => value.Id == playlistId,
            cancellationToken);
        var version = await dbContext.PlaylistVersions.SingleOrDefaultAsync(
            value => value.Id == versionId && value.PlaylistId == playlistId,
            cancellationToken);
        if (playlist is null || version is null)
        {
            return NotFound();
        }

        var items = await dbContext.PlaylistItems
            .Where(value => value.PlaylistVersionId == versionId)
            .ToListAsync(cancellationToken);
        var contentIds = items.Select(value => value.ContentVersionId).ToArray();
        var cleanCount = await dbContext.ContentVersions.CountAsync(
            value => contentIds.Contains(value.Id) && value.ApprovedAtUtc != null && value.ScanState == "clean",
            cancellationToken);
        if (items.Count == 0 || cleanCount != items.Count)
        {
            return ConflictProblem("playlist_content_unavailable", "Playlist content is no longer publishable.");
        }

        try
        {
            var actorId = CurrentUserId();
            var nowUtc = timeProvider.GetUtcNow();
            version.Publish(actorId, nowUtc);
            AddAudit(tenantId, actorId, "playlist.published", playlist.Id, new { versionId }, nowUtc);
            await dbContext.SaveChangesAsync(cancellationToken);
            return Ok(ToResponse(playlist, version, items.Count));
        }
        catch (InvalidOperationException)
        {
            return ConflictProblem("playlist_already_published", "The playlist version is already immutable.");
        }
    }

    private void AddAudit(Guid tenantId, Guid actorId, string action, Guid targetId, object details, DateTimeOffset atUtc) =>
        dbContext.AuditEvents.Add(new TenantAuditEvent(
            Guid.NewGuid(),
            tenantId,
            "user",
            actorId,
            action,
            "playlist",
            targetId,
            "success",
            null,
            HttpContext.TraceIdentifierGuid(),
            JsonSerializer.Serialize(details),
            atUtc));

    private Guid CurrentUserId() => Guid.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var userId)
        ? userId
        : throw new InvalidOperationException("Authenticated principal has no valid user identifier.");

    private static PlaylistResponse ToResponse(Playlist playlist, PlaylistVersion? version, int itemCount) => new(
        playlist.Id,
        playlist.Name,
        playlist.Description,
        playlist.UpdatedAtUtc,
        playlist.ConcurrencyToken,
        version is null
            ? null
            : new PlaylistVersionResponse(
                version.Id,
                version.VersionNumber,
                version.PublicationState,
                version.CreatedAtUtc,
                version.PublishedAtUtc,
                itemCount));

    private static ObjectResult InvalidPlaylist(string code, string title) => new(new ProblemDetails
    {
        Type = "https://docs.example.invalid/problems/playlist-validation",
        Title = title,
        Status = StatusCodes.Status400BadRequest,
        Extensions = { ["code"] = code }
    })
    {
        StatusCode = StatusCodes.Status400BadRequest
    };

    private static ObjectResult ConflictProblem(string code, string title) => new(new ProblemDetails
    {
        Type = "https://docs.example.invalid/problems/resource-state",
        Title = title,
        Status = StatusCodes.Status409Conflict,
        Extensions = { ["code"] = code }
    })
    {
        StatusCode = StatusCodes.Status409Conflict
    };
}

public sealed record CreatePlaylistRequest(
    [param: Required, StringLength(200, MinimumLength = 1)] string Name,
    [param: StringLength(2000)] string? Description,
    [param: Required] IReadOnlyList<CreatePlaylistItemRequest> Items);

public sealed record CreatePlaylistItemRequest(
    Guid ContentVersionId,
    [param: Range(1000, 86_400_000)] int? DurationMilliseconds,
    bool LoopVideo = false);

public sealed record PlaylistResponse(
    Guid Id,
    string Name,
    string? Description,
    DateTimeOffset UpdatedAtUtc,
    Guid ConcurrencyToken,
    PlaylistVersionResponse? LatestVersion);

public sealed record PlaylistVersionResponse(
    Guid Id,
    int VersionNumber,
    string PublicationState,
    DateTimeOffset CreatedAtUtc,
    DateTimeOffset? PublishedAtUtc,
    int ItemCount);
