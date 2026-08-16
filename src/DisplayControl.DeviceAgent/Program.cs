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
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddHttpClient<DeviceControlClient>();
builder.Services.AddHostedService<Worker>();

var app = builder.Build();
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
app.MapGet("/player/v1/health", () => Results.Ok(new { status = "healthy" }));
app.MapGet("/player/v1/manifest", (PlayerStateStore state) => state.ManifestSnapshot() is { } manifest
    ? Results.Ok(manifest)
    : Results.NotFound());
app.MapGet("/player/v1/assets/{contentVersionId:guid}", (Guid contentVersionId, PlayerStateStore state) =>
    state.TryResolveAsset(contentVersionId, out var asset) && asset is not null
        ? Results.File(asset.Path, asset.ContentType, enableRangeProcessing: true)
        : Results.NotFound());
app.MapFallbackToFile("index.html");

await app.RunAsync();
