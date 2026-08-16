using Microsoft.Extensions.Options;

namespace DisplayControl.DeviceAgent;

public sealed class Worker(
    ILogger<Worker> logger,
    DeviceControlClient controlClient,
    PlayerStateStore playerState,
    IOptions<AgentRuntimeOptions> runtimeOptions) : BackgroundService
{
    private readonly AgentRuntimeOptions _runtimeOptions = runtimeOptions.Value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        AgentLog.Started(logger);
        playerState.SetNotLicensed("startup_fail_closed");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await controlClient.SynchronizeOnceAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                playerState.SetNotLicensed("agent_cycle_failed");
                AgentLog.CycleFailed(logger, exception.GetType().Name);
            }

            var jitterMilliseconds = Random.Shared.Next(0, 2001);
            var delay = TimeSpan.FromSeconds(_runtimeOptions.HeartbeatIntervalSeconds)
                .Add(TimeSpan.FromMilliseconds(jitterMilliseconds));
            await Task.Delay(delay, stoppingToken);
        }
    }
}

internal static partial class AgentLog
{
    [LoggerMessage(1000, LogLevel.Information, "Display agent started in fail-closed mode.")]
    public static partial void Started(ILogger logger);

    [LoggerMessage(1001, LogLevel.Warning, "The device synchronization cycle failed with safe error type {ErrorType}.")]
    public static partial void CycleFailed(ILogger logger, string errorType);
}
