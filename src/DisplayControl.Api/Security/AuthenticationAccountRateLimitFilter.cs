using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Caching.Memory;

namespace DisplayControl.Api.Security;

public sealed class AuthenticationAccountRateLimitFilter(
    AuthenticationAccountRateLimiter accountRateLimiter) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var rateLimitAttribute = context.ActionDescriptor.EndpointMetadata
            .OfType<EnableRateLimitingAttribute>()
            .FirstOrDefault();
        if (!string.Equals(rateLimitAttribute?.PolicyName, "authentication", StringComparison.Ordinal))
        {
            await next();
            return;
        }

        var key = FindAccountKey(context);
        if (key is null || accountRateLimiter.TryAcquire(key))
        {
            await next();
            return;
        }

        context.Result = new ObjectResult(new ProblemDetails
        {
            Type = "https://docs.example.invalid/problems/rate-limit",
            Title = "Too many authentication attempts. Try again later.",
            Status = StatusCodes.Status429TooManyRequests,
            Extensions = { ["code"] = "authentication_rate_limited" }
        })
        {
            StatusCode = StatusCodes.Status429TooManyRequests
        };
    }

    private static string? FindAccountKey(ActionExecutingContext context)
    {
        foreach (var argument in context.ActionArguments.Values.Where(value => value is not null))
        {
            var email = argument!.GetType().GetProperty("Email")?.GetValue(argument) as string;
            if (!string.IsNullOrWhiteSpace(email))
            {
                return "email:" + email.Trim().ToUpperInvariant();
            }

            var token = argument.GetType().GetProperty("Token")?.GetValue(argument) as string;
            if (!string.IsNullOrWhiteSpace(token))
            {
                return "token:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
            }
        }

        return context.HttpContext.User.FindFirstValue(ClaimTypes.NameIdentifier) is { Length: > 0 } userId
            ? "user:" + userId
            : null;
    }
}

public sealed class AuthenticationAccountRateLimiter(IMemoryCache cache)
{
    private readonly object _gate = new();
    private readonly MemoryCacheEntryOptions _entryOptions = new MemoryCacheEntryOptions()
        .SetSize(1)
        .SetSlidingExpiration(TimeSpan.FromMinutes(30))
        .RegisterPostEvictionCallback(static (_, value, _, _) => (value as IDisposable)?.Dispose());

    public bool TryAcquire(string key)
    {
        lock (_gate)
        {
            var limiter = cache.GetOrCreate(key, entry =>
            {
                entry.SetOptions(_entryOptions);
                return new SlidingWindowRateLimiter(new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 10,
                    Window = TimeSpan.FromMinutes(5),
                    SegmentsPerWindow = 5,
                    QueueLimit = 0,
                    AutoReplenishment = true
                });
            }) ?? throw new InvalidOperationException("Authentication account limiter could not be created.");
            using var lease = limiter.AttemptAcquire();
            return lease.IsAcquired;
        }
    }
}
