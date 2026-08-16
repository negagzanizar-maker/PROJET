using System.Security.Cryptography;

using DisplayControl.Application.Tenancy;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Testcontainers.PostgreSql;

namespace DisplayControl.IntegrationTests.Database;

public sealed class PostgreSqlRlsTests : IAsyncLifetime
{
    private const string RuntimeRole = "display_control_runtime";
    private const string RuntimeLogin = "display_control_runtime_test";
    private static readonly string RuntimePassword = Convert.ToBase64String(RandomNumberGenerator.GetBytes(24));

    private static readonly Guid TenantA = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    private static readonly Guid TenantB = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
    private static readonly string[] ProtectedTables =
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
        "tenant_memberships",
        "tenants"
    ];

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:18.4-alpine3.24")
        .WithDatabase("display_control_tests")
        .WithUsername("postgres")
        .WithPassword("ephemeral-owner-test-only-V8s4Q2x9")
        .Build();

    private string RuntimeConnectionString
    {
        get
        {
            var builder = new NpgsqlConnectionStringBuilder(_postgres.GetConnectionString())
            {
                Username = RuntimeLogin,
                Password = RuntimePassword,
                Pooling = true,
                MinPoolSize = 0,
                MaxPoolSize = 1
            };

            return builder.ConnectionString;
        }
    }

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        var options = new DbContextOptionsBuilder<DisplayControlDbContext>()
            .UseNpgsql(_postgres.GetConnectionString())
            .Options;

        await using (var context = new DisplayControlDbContext(options, NullTenant.Instance))
        {
            await context.Database.MigrateAsync();
        }

        await using var ownerConnection = new NpgsqlConnection(_postgres.GetConnectionString());
        await ownerConnection.OpenAsync();

        await ExecuteOwnerSetupAsync(ownerConnection);
        await SeedTwoTenantsAsync(ownerConnection);
    }

    public async Task DisposeAsync()
    {
        await _postgres.DisposeAsync();
    }

    [Fact]
    public async Task RuntimeRoleHasNoBypassAndProtectedTablesForceRls()
    {
        await using var connection = new NpgsqlConnection(_postgres.GetConnectionString());
        await connection.OpenAsync();

        const string roleSql =
            "SELECT rolsuper, rolbypassrls, rolcreaterole, rolcreatedb FROM pg_roles WHERE rolname = @role";
        await using (var roleCommand = new NpgsqlCommand(roleSql, connection))
        {
            roleCommand.Parameters.AddWithValue("role", RuntimeRole);
            await using var reader = await roleCommand.ExecuteReaderAsync();
            Assert.True(await reader.ReadAsync());
            Assert.False(reader.GetBoolean(0));
            Assert.False(reader.GetBoolean(1));
            Assert.False(reader.GetBoolean(2));
            Assert.False(reader.GetBoolean(3));
        }

        const string tableSql =
            """
            SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'app'
              AND c.relname = ANY(@tables)
            ORDER BY c.relname
            """;
        await using var tableCommand = new NpgsqlCommand(tableSql, connection);
        tableCommand.Parameters.AddWithValue("tables", ProtectedTables);
        await using var tableReader = await tableCommand.ExecuteReaderAsync();

        var observed = 0;
        while (await tableReader.ReadAsync())
        {
            Assert.True(tableReader.GetBoolean(1), $"RLS is disabled for {tableReader.GetString(0)}.");
            Assert.True(tableReader.GetBoolean(2), $"Forced RLS is disabled for {tableReader.GetString(0)}.");
            observed++;
        }

        Assert.Equal(ProtectedTables.Length, observed);
    }

    [Fact]
    public async Task MissingAndCrossTenantContextCannotReadOrWriteDevices()
    {
        await using var dataSource = NpgsqlDataSource.Create(RuntimeConnectionString);

        await using (var noContextConnection = await dataSource.OpenConnectionAsync())
        {
            Assert.Equal(0, await CountDevicesAsync(noContextConnection));
        }

        await using (var tenantAConnection = await dataSource.OpenConnectionAsync())
        await using (var transaction = await tenantAConnection.BeginTransactionAsync())
        {
            await SetTenantAsync(tenantAConnection, TenantA);
            Assert.Equal(1, await CountDevicesAsync(tenantAConnection));

            var exception = await Assert.ThrowsAsync<PostgresException>(() =>
                InsertDeviceAsync(tenantAConnection, TenantB, Guid.NewGuid(), "Forbidden B device"));
            Assert.Equal(PostgresErrorCodes.InsufficientPrivilege, exception.SqlState);

            await transaction.RollbackAsync();
        }

        await using (var reusedWithoutContext = await dataSource.OpenConnectionAsync())
        {
            Assert.Equal(0, await CountDevicesAsync(reusedWithoutContext));
        }

        await using (var tenantBConnection = await dataSource.OpenConnectionAsync())
        await using (var transaction = await tenantBConnection.BeginTransactionAsync())
        {
            await SetTenantAsync(tenantBConnection, TenantB);
            Assert.Equal(1, await CountDevicesAsync(tenantBConnection));
            await transaction.RollbackAsync();
        }
    }

    private static async Task ExecuteOwnerSetupAsync(NpgsqlConnection connection)
    {
        const string sql =
            """
            CREATE ROLE display_control_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
            CREATE ROLE display_control_runtime_test LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
            GRANT display_control_runtime TO display_control_runtime_test;
            GRANT USAGE ON SCHEMA app TO display_control_runtime;
            GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO display_control_runtime;
            GRANT SELECT ON
                app.identity_role_claims,
                app.identity_roles,
                app.system_key_metadata,
                app.tenants
            TO display_control_runtime;
            GRANT SELECT, INSERT ON
                app.audit_events,
                app.device_heartbeats,
                app.device_synchronization_events,
                app.license_events
            TO display_control_runtime;
            GRANT SELECT, INSERT, UPDATE ON
                app.content_assets,
                app.content_versions,
                app.desired_state_assets,
                app.desired_states,
                app.device_certificates,
                app.devices,
                app.enrollment_tokens,
                app.identity_users,
                app.invitations,
                app.licenses,
                app.playlists,
                app.playlist_versions,
                app.tenant_memberships
            TO display_control_runtime;
            GRANT SELECT, INSERT, UPDATE, DELETE ON
                app.device_assignments,
                app.device_group_members,
                app.device_groups,
                app.device_network_interfaces,
                app.group_assignments,
                app.identity_user_claims,
                app.identity_user_logins,
                app.identity_user_roles,
                app.identity_user_tokens,
                app.outbox_messages,
                app.playlist_items,
                app.user_mfa_secrets,
                app.user_recovery_codes,
                app.user_sessions
            TO display_control_runtime;
            GRANT INSERT ON app.identity_notifications TO display_control_runtime;
            """;

        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();

        const string quotePasswordSql =
            "SELECT format('ALTER ROLE display_control_runtime_test PASSWORD %L', @password)";
        await using var quotePasswordCommand = new NpgsqlCommand(quotePasswordSql, connection);
        quotePasswordCommand.Parameters.AddWithValue("password", RuntimePassword);
        var quotedPasswordCommand = (string?)await quotePasswordCommand.ExecuteScalarAsync()
            ?? throw new InvalidOperationException("PostgreSQL did not produce password DDL.");
        await using var passwordCommand = new NpgsqlCommand(quotedPasswordCommand, connection);
        await passwordCommand.ExecuteNonQueryAsync();
    }

    private static async Task SeedTwoTenantsAsync(NpgsqlConnection connection)
    {
        const string tenantSql =
            """
            INSERT INTO app.tenants
                (id, name, slug, time_zone, state, created_at_utc, updated_at_utc, concurrency_token)
            VALUES
                (@tenantA, 'Tenant A', 'tenant-a', 'UTC', 'Active', now(), now(), gen_random_uuid()),
                (@tenantB, 'Tenant B', 'tenant-b', 'UTC', 'Active', now(), now(), gen_random_uuid());
            """;
        await using (var tenantCommand = new NpgsqlCommand(tenantSql, connection))
        {
            tenantCommand.Parameters.AddWithValue("tenantA", TenantA);
            tenantCommand.Parameters.AddWithValue("tenantB", TenantB);
            await tenantCommand.ExecuteNonQueryAsync();
        }

        await InsertDeviceAsync(connection, TenantA, Guid.NewGuid(), "Tenant A device");
        await InsertDeviceAsync(connection, TenantB, Guid.NewGuid(), "Tenant B device");
    }

    private static async Task SetTenantAsync(NpgsqlConnection connection, Guid tenantId)
    {
        const string sql = "SELECT set_config('app.tenant_id', @tenantId, true)";
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("tenantId", tenantId.ToString());
        await command.ExecuteScalarAsync();
    }

    private static async Task<int> CountDevicesAsync(NpgsqlConnection connection)
    {
        await using var command = new NpgsqlCommand("SELECT count(*) FROM app.devices", connection);
        var count = (long)(await command.ExecuteScalarAsync() ?? 0L);
        return checked((int)count);
    }

    private static async Task InsertDeviceAsync(
        NpgsqlConnection connection,
        Guid tenantId,
        Guid deviceId,
        string displayName)
    {
        const string sql =
            """
            INSERT INTO app.devices
                (id, tenant_id, display_name, state, created_at_utc, updated_at_utc, concurrency_token)
            VALUES
                (@id, @tenantId, @displayName, 'PendingEnrollment', now(), now(), gen_random_uuid());
            """;
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", deviceId);
        command.Parameters.AddWithValue("tenantId", tenantId);
        command.Parameters.AddWithValue("displayName", displayName);
        await command.ExecuteNonQueryAsync();
    }

    private sealed class NullTenant : ICurrentTenant
    {
        public static NullTenant Instance { get; } = new();

        public Guid? TenantId => null;
    }
}
