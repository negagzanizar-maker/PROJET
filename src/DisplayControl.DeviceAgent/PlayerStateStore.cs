namespace DisplayControl.DeviceAgent;

public sealed class PlayerStateStore(TimeProvider timeProvider)
{
    private readonly object _gate = new();
    private PlayerStateSnapshot _state = new(
        "notLicensed",
        "Not licensed",
        null,
        null,
        null,
        DateTimeOffset.MinValue);
    private ActivePlayerManifest? _manifest;
    private Dictionary<Guid, PlayerAssetFile> _assetFiles =
        new Dictionary<Guid, PlayerAssetFile>();

    public PlayerStateSnapshot Snapshot()
    {
        lock (_gate)
        {
            return _state;
        }
    }

    public PlayerManifestSnapshot? ManifestSnapshot()
    {
        lock (_gate)
        {
            return _manifest is null
                ? null
                : new PlayerManifestSnapshot(
                    _manifest.DesiredStateId,
                    _manifest.Version,
                    _manifest.Assets.Select(value => new PlayerManifestAssetSnapshot(
                        value.ContentVersionId,
                        value.Position,
                        value.MediaKind,
                        value.DurationMilliseconds,
                        value.LoopVideo,
                        $"/player/v1/assets/{value.ContentVersionId:D}")).ToArray());
        }
    }

    public bool IsReady(long desiredStateVersion)
    {
        lock (_gate)
        {
            return _state.Status == "ready" && _manifest?.Version == desiredStateVersion;
        }
    }

    public bool TryResolveAsset(Guid contentVersionId, out PlayerAssetFile? asset)
    {
        lock (_gate)
        {
            return _assetFiles.TryGetValue(contentVersionId, out asset);
        }
    }

    public IReadOnlySet<string> ActiveAssetHashesSnapshot()
    {
        lock (_gate)
        {
            return _assetFiles.Values.Select(value => value.Sha256).ToHashSet(StringComparer.Ordinal);
        }
    }

    public void SetNotLicensed(string? safeReasonCode = null)
    {
        lock (_gate)
        {
            _manifest = null;
            _assetFiles = new Dictionary<Guid, PlayerAssetFile>();
            Set("notLicensed", "Not licensed", safeReasonCode, null, null);
        }
    }

    public void SetLicensedNoContent(Guid deviceId)
    {
        lock (_gate)
        {
            _manifest = null;
            _assetFiles = new Dictionary<Guid, PlayerAssetFile>();
            Set("noContent", "No content assigned", null, deviceId, null);
        }
    }

    public void SetSynchronizing(Guid deviceId, long desiredStateVersion)
    {
        lock (_gate)
        {
            _manifest = null;
            _assetFiles = new Dictionary<Guid, PlayerAssetFile>();
            Set("synchronizing", "Synchronizing", null, deviceId, desiredStateVersion);
        }
    }

    public void SetReady(
        Guid deviceId,
        ActivePlayerManifest manifest,
        IReadOnlyDictionary<Guid, PlayerAssetFile> assetFiles)
    {
        ArgumentNullException.ThrowIfNull(manifest);
        ArgumentNullException.ThrowIfNull(assetFiles);
        lock (_gate)
        {
            _manifest = manifest;
            _assetFiles = new Dictionary<Guid, PlayerAssetFile>(assetFiles);
            Set("ready", "Playing", null, deviceId, manifest.Version);
        }
    }

    private void Set(string status, string message, string? safeReasonCode, Guid? deviceId, long? version) =>
        _state = new PlayerStateSnapshot(
            status,
            message,
            safeReasonCode,
            deviceId,
            version,
            timeProvider.GetUtcNow());
}

public sealed record PlayerStateSnapshot(
    string Status,
    string Message,
    string? SafeReasonCode,
    Guid? DeviceId,
    long? DesiredStateVersion,
    DateTimeOffset UpdatedAtUtc);

public sealed record ActivePlayerManifest(
    Guid DesiredStateId,
    long Version,
    IReadOnlyList<ActivePlayerAsset> Assets);

public sealed record ActivePlayerAsset(
    Guid ContentVersionId,
    int Position,
    string MediaKind,
    int? DurationMilliseconds,
    bool LoopVideo);

public sealed record PlayerAssetFile(string Path, string ContentType, long ByteLength, string Sha256);

public sealed record PlayerManifestSnapshot(
    Guid DesiredStateId,
    long Version,
    IReadOnlyList<PlayerManifestAssetSnapshot> Assets);

public sealed record PlayerManifestAssetSnapshot(
    Guid ContentVersionId,
    int Position,
    string MediaKind,
    int? DurationMilliseconds,
    bool LoopVideo,
    string Url);
