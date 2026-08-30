using System.Net.Sockets;
using System.Security.Cryptography.X509Certificates;
using DisplayControl.Api.Notifications;
using DisplayControl.Application.Content;
using DisplayControl.Application.Security;
using DisplayControl.Application.Storage;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;

namespace DisplayControl.Api.Operations;

public sealed class DependencyReadinessHealthCheck(
    IServiceScopeFactory scopeFactory,
    IPrivateObjectStore objectStore,
    IContentMalwareScanner malwareScanner,
    ILicenseLeaseSigner leaseSigner,
    IDeviceCertificateIssuer certificateIssuer,
    IServiceProvider serviceProvider,
    TimeProvider timeProvider) : IHealthCheck
{
    private static readonly Guid ReadinessStorageTenantId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using (var scope = scopeFactory.CreateAsyncScope())
            {
                var dbContext = scope.ServiceProvider.GetRequiredService<DisplayControlDbContext>();
                if (!await dbContext.Database.CanConnectAsync(cancellationToken))
                {
                    return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
                }
            }

            var storageKey = new PrivateObjectKey(ReadinessStorageTenantId, Guid.NewGuid());
            try
            {
                await objectStore.PutAsync(storageKey, Stream.Null, 0, cancellationToken);
                if (!await objectStore.ExistsAsync(storageKey, cancellationToken))
                {
                    return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
                }
            }
            finally
            {
                await objectStore.DeleteAsync(storageKey, cancellationToken);
            }

            var verificationKey = leaseSigner.VerificationKey;
            if (!string.Equals(verificationKey.Algorithm, "ES256", StringComparison.Ordinal) ||
                string.IsNullOrWhiteSpace(verificationKey.KeyId) ||
                string.IsNullOrWhiteSpace(verificationKey.SubjectPublicKeyInfoPem))
            {
                return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
            }

            using var certificateAuthority = X509Certificate2.CreateFromPem(certificateIssuer.CertificateAuthorityPem);
            var nowUtc = timeProvider.GetUtcNow();
            if (nowUtc < certificateAuthority.NotBefore.ToUniversalTime() ||
                nowUtc >= certificateAuthority.NotAfter.ToUniversalTime() ||
                !certificateAuthority.Extensions.OfType<X509BasicConstraintsExtension>()
                    .Any(extension => extension.CertificateAuthority))
            {
                return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
            }

            if (!await malwareScanner.IsReadyAsync(cancellationToken))
            {
                return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
            }

            if (serviceProvider.GetService<NotificationDeliveryOptions>() is { } notifications &&
                !await NotificationWorkerDependenciesAreReadyAsync(notifications, cancellationToken))
            {
                return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
            }

            return HealthCheckResult.Healthy();
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            return HealthCheckResult.Unhealthy("A required dependency is unavailable.");
        }
    }

    private static async Task<bool> NotificationWorkerDependenciesAreReadyAsync(
        NotificationDeliveryOptions options,
        CancellationToken cancellationToken)
    {
        using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutSource.CancelAfter(TimeSpan.FromSeconds(5));
        try
        {
            await using var connection = new NpgsqlConnection(options.DatabaseConnectionString);
            await connection.OpenAsync(timeoutSource.Token);
            await using (var command = new NpgsqlCommand("SELECT 1", connection))
            {
                await command.ExecuteScalarAsync(timeoutSource.Token);
            }

            using var smtp = new TcpClient();
            await smtp.ConnectAsync(options.SmtpHost, options.SmtpPort, timeoutSource.Token);
            return smtp.Connected;
        }
        catch (Exception exception) when (
            exception is NpgsqlException or SocketException or IOException or OperationCanceledException)
        {
            return false;
        }
    }
}
