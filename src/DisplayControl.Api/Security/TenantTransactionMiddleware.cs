using DisplayControl.Infrastructure.Persistence;
using DisplayControl.Infrastructure.Tenancy;

namespace DisplayControl.Api.Security;

public sealed class TenantTransactionMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(
        HttpContext context,
        ScopedTenantContext tenantContext,
        DisplayControlDbContext dbContext)
    {
        if (tenantContext.TenantId is not Guid tenantId)
        {
            await next(context);
            return;
        }

        if (context.GetEndpoint()?.Metadata.GetMetadata<SkipTenantTransactionAttribute>() is not null)
        {
            await next(context);
            return;
        }

        if (dbContext.Database.CurrentTransaction is not null)
        {
            await next(context);
            return;
        }

        await using var transaction = await dbContext.BeginTenantTransactionAsync(tenantId, context.RequestAborted);
        await next(context);
        await transaction.CommitAsync(context.RequestAborted);
    }
}

[AttributeUsage(AttributeTargets.Method)]
public sealed class SkipTenantTransactionAttribute : Attribute;
