using DisplayControl.DeviceAgent;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
{
    options.AddServerHeader = false;
    options.ListenLocalhost(8787);
});

builder.Services
    .AddOptions<AgentRuntimeOptions>()
    .BindConfiguration(AgentRuntimeOptions.SectionName)
    .Validate(AgentRuntimeOptions.IsValid, "Agent settings are invalid or unsafe.")
    .ValidateOnStart();
builder.Services.AddSingleton<AgentStateStore>();
builder.Services.AddSingleton<ContentCacheStore>();
builder.Services.AddSingleton<DeviceInventoryCollector>();
builder.Services.AddSingleton<PlayerStateStore>();
builder.Services.AddSingleton<AgentHealthStore>();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddHttpClient<DeviceControlClient>();
builder.Services.AddHostedService<Worker>();

var app = builder.Build();
var releaseVersionPath = Path.Combine(AppContext.BaseDirectory, "release-version");
var releaseVersion = File.Exists(releaseVersionPath) ? File.ReadAllText(releaseVersionPath).Trim() : null;
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers.XContentTypeOptions = "nosniff";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        context.Response.Headers.Append(
            "Content-Security-Policy",
            "default-src 'self'; img-src 'self' data:; media-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
        context.Response.Headers.Append(
            "Permissions-Policy",
            "camera=(), microphone=(), geolocation=(), payment=(), usb=()");
        return Task.CompletedTask;
    });
    await next(context);
});
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapGet("/player/v1/state", (PlayerStateStore state) => Results.Ok(state.Snapshot()));
app.MapPost("/player/v1/playback-report", (HttpContext context, PlaybackReport report, PlayerStateStore state) =>
{
    // Browsers must originate from this loopback application, never a remote website.
    var origin = context.Request.Headers.Origin.ToString();
    if (!string.Equals(origin, $"{context.Request.Scheme}://{context.Request.Host}", StringComparison.Ordinal))
        return Results.StatusCode(StatusCodes.Status403Forbidden);
    return state.ReportPlayback(report) ? Results.NoContent() : Results.BadRequest();
});
app.MapGet("/player/v1/health", (AgentHealthStore health, PlayerStateStore state,
    Microsoft.Extensions.Options.IOptions<AgentRuntimeOptions> options) =>
{
    var fresh = health.IsFresh(options.Value.HeartbeatIntervalSeconds);
    return Results.Json(new
    {
        status = fresh ? "healthy" : "degraded",
        player = state.Snapshot(),
        version = typeof(AgentHealthStore).Assembly.GetName().Version?.ToString(),
        releaseVersion
    },
        statusCode: fresh ? 200 : 503);
});
app.MapGet("/player/v1/manifest", (PlayerStateStore state) => state.ManifestSnapshot() is { } manifest
    ? Results.Ok(manifest)
    : Results.NotFound());
app.MapGet("/player/v1/assets/{contentVersionId:guid}", (Guid contentVersionId, PlayerStateStore state) =>
    state.TryResolveAsset(contentVersionId, out var asset) && asset is not null
        ? Results.File(asset.Path, asset.ContentType, enableRangeProcessing: true)
        : Results.NotFound());
app.MapFallbackToFile("index.html");

await app.RunAsync();
