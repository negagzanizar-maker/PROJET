using DisplayControl.Application.Tenancy;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

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

    private sealed class NullTenant : ICurrentTenant
    {
        public static NullTenant Instance { get; } = new();

        public Guid? TenantId => null;
    }
}
