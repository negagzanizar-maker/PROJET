using DisplayControl.Application.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace DisplayControl.Infrastructure.Persistence;

public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<DisplayControlDbContext>
{
    public DisplayControlDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("DISPLAYCONTROL_MIGRATION_CONNECTION")
            ?? "Host=127.0.0.1;Port=5432;Database=display_control_design;Username=design_only;Password=not-used-for-model-generation";

        var options = new DbContextOptionsBuilder<DisplayControlDbContext>()
            .UseNpgsql(connectionString, npgsql =>
                npgsql.MigrationsAssembly(typeof(DisplayControlDbContext).Assembly.FullName))
            .Options;

        return new DisplayControlDbContext(options, NullTenantContext.Instance);
    }

    private sealed class NullTenantContext : ICurrentTenant
    {
        public static NullTenantContext Instance { get; } = new();

        public Guid? TenantId => null;
    }
}
