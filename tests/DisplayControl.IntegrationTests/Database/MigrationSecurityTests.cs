using DisplayControl.Application.Tenancy;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql;
using Testcontainers.PostgreSql;

namespace DisplayControl.IntegrationTests.Database;

public sealed class MigrationSecurityTests
{
    private static readonly string[] TenantTables =
    [
        "audit_events",
        "content_assets",
        "content_versions",
        "desired_state_assets",
        "desired_states",
        "device_assignments",
        "device_certificates",
        "device_group_members",
        "device_groups",
        "device_heartbeats",
        "device_network_interfaces",
        "device_synchronization_events",
        "devices",
        "enrollment_tokens",
        "group_assignments",
        "identity_notifications",
        "invitations",
        "license_events",
        "licenses",
        "outbox_messages",
        "playlist_items",
        "playlist_versions",
        "playlists",
        "tenant_memberships"
    ];

    [Fact]
    public void MigrationScriptForcesRlsAndCreatesFailClosedPolicies()
    {
        var options = new DbContextOptionsBuilder<DisplayControlDbContext>()
            .UseNpgsql("Host=127.0.0.1;Database=offline_migration_check;Username=unused;Password=unused")
            .Options;

        using var context = new DisplayControlDbContext(options, NullTenant.Instance);
        var migrator = context.GetService<IMigrator>();
        var script = migrator.GenerateScript(options: MigrationsSqlGenerationOptions.Default);
        var mappedTenantTables = context.Model.GetEntityTypes()
            .Where(entityType => entityType.FindProperty("TenantId") is not null)
            .Select(entityType => entityType.GetTableName())
            .Where(tableName => tableName is not null)
            .Cast<string>()
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.Equal(TenantTables.Order(StringComparer.Ordinal), mappedTenantTables);

        Assert.Contains("ALTER TABLE app.tenants ENABLE ROW LEVEL SECURITY;", script, StringComparison.Ordinal);
        Assert.Contains("ALTER TABLE app.tenants FORCE ROW LEVEL SECURITY;", script, StringComparison.Ordinal);
        Assert.Contains(
            "USING (id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)",
            script,
            StringComparison.Ordinal);
        Assert.Contains(
            "CREATE POLICY tenants_platform_catalog_select ON app.tenants",
            script,
            StringComparison.Ordinal);
        Assert.Contains(
            "CREATE POLICY identity_notifications_delivery_select ON app.identity_notifications",
            script,
            StringComparison.Ordinal);
        Assert.Contains(
            "CREATE POLICY identity_notifications_delivery_update ON app.identity_notifications",
            script,
            StringComparison.Ordinal);
        Assert.Contains(
            "CREATE POLICY device_heartbeats_retention_delete ON app.device_heartbeats",
            script,
            StringComparison.Ordinal);
        Assert.Contains(
            "current_user = 'display_control_maintenance'",
            script,
            StringComparison.Ordinal);

        foreach (var table in TenantTables)
        {
            Assert.Contains($"ALTER TABLE app.{table} ENABLE ROW LEVEL SECURITY;", script, StringComparison.Ordinal);
            Assert.Contains($"ALTER TABLE app.{table} FORCE ROW LEVEL SECURITY;", script, StringComparison.Ordinal);
            Assert.Contains($"CREATE POLICY {table}_tenant_isolation ON app.{table}", script, StringComparison.Ordinal);
        }

        Assert.DoesNotContain(
            "ALTER TABLE app.system_key_metadata ENABLE ROW LEVEL SECURITY;",
            script,
            StringComparison.Ordinal);
    }

    [Fact]
    public async Task HeartbeatMigrationBackfillsValidLegacyIdempotencyValues()
    {
        await using var postgres = new PostgreSqlBuilder("postgres:18.4-alpine3.24")
            .WithDatabase("display_control_migration_tests")
            .WithUsername("postgres")
            .WithPassword("ephemeral-migration-test-V7m2Q9x4")
            .Build();
        await postgres.StartAsync();

        var options = new DbContextOptionsBuilder<DisplayControlDbContext>()
            .UseNpgsql(postgres.GetConnectionString())
            .Options;
        await using (var context = new DisplayControlDbContext(options, NullTenant.Instance))
        {
            var migrator = context.GetService<IMigrator>();
            await migrator.MigrateAsync("20260815204800_AllowUserlessInvitationNotifications");
        }

        var tenantId = Guid.NewGuid();
        var deviceId = Guid.NewGuid();
        var heartbeatId = Guid.NewGuid();
        await using (var connection = new NpgsqlConnection(postgres.GetConnectionString()))
        {
            await connection.OpenAsync();
            const string seedSql =
                """
                INSERT INTO app.tenants
                    (id, name, slug, time_zone, state, created_at_utc, updated_at_utc, concurrency_token)
                VALUES
                    (@tenantId, 'Migration tenant', 'migration-tenant', 'UTC', 'Active', now(), now(), gen_random_uuid());

                INSERT INTO app.devices
                    (id, tenant_id, display_name, state, created_at_utc, updated_at_utc, concurrency_token)
                VALUES
                    (@deviceId, @tenantId, 'Legacy device', 'Active', now(), now(), gen_random_uuid());

                INSERT INTO app.device_heartbeats
                    (id, tenant_id, device_id, sequence, reported_sent_at_utc, received_at_utc,
                     server_observed_ip, inventory_json, applied_desired_state_version,
                     player_state_code, free_disk_bytes, last_error_code, correlation_id)
                VALUES
                    (@heartbeatId, @tenantId, @deviceId, 7, now(), now(),
                     '127.0.0.1', '{}'::jsonb, NULL, 'notLicensed', 1024, NULL, gen_random_uuid());
                """;
            await using var seed = new NpgsqlCommand(seedSql, connection);
            seed.Parameters.AddWithValue("tenantId", tenantId);
            seed.Parameters.AddWithValue("deviceId", deviceId);
            seed.Parameters.AddWithValue("heartbeatId", heartbeatId);
            await seed.ExecuteNonQueryAsync();
        }

        await using (var context = new DisplayControlDbContext(options, NullTenant.Instance))
        {
            await context.Database.MigrateAsync();
        }

        await using (var connection = new NpgsqlConnection(postgres.GetConnectionString()))
        {
            await connection.OpenAsync();
            const string verifySql =
                """
                SELECT boot_id, octet_length(request_sha256), response_json
                FROM app.device_heartbeats
                WHERE id = @heartbeatId;
                """;
            await using var verify = new NpgsqlCommand(verifySql, connection);
            verify.Parameters.AddWithValue("heartbeatId", heartbeatId);
            await using var reader = await verify.ExecuteReaderAsync();
            Assert.True(await reader.ReadAsync());
            Assert.Equal(heartbeatId, reader.GetGuid(0));
            Assert.Equal(32, reader.GetInt32(1));
            Assert.True(await reader.IsDBNullAsync(2));
        }
    }

    private sealed class NullTenant : ICurrentTenant
    {
        public static NullTenant Instance { get; } = new();

        public Guid? TenantId => null;
    }
}
