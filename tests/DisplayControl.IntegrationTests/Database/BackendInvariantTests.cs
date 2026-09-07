using System.Security.Claims;
using DisplayControl.Api.Controllers;
using DisplayControl.Api.Scheduling;
using DisplayControl.Api.Security;
using DisplayControl.Application.Content;
using DisplayControl.Domain.Content;
using DisplayControl.Domain.Devices;
using DisplayControl.Domain.Licensing;
using DisplayControl.Domain.Playlists;
using DisplayControl.Domain.Scheduling;
using DisplayControl.Domain.Tenancy;
using DisplayControl.Infrastructure.Persistence;
using DisplayControl.Infrastructure.Tenancy;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Controllers;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Testcontainers.PostgreSql;

namespace DisplayControl.IntegrationTests.Database;

public sealed class BackendInvariantTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:18.4-alpine3.24")
        .WithDatabase("backend_invariants").WithUsername("postgres")
        .WithPassword("ephemeral-test-only-Y7m5F2b9").Build();
    private readonly Guid _tenantId = Guid.NewGuid();
    private readonly Guid _actorId = Guid.NewGuid();
    private static DateTimeOffset Now => DateTimeOffset.UtcNow;

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
        db.Tenants.Add(new Tenant(_tenantId, "Regression tenant", "regression", "UTC", Now));
        await db.SaveChangesAsync();
    }

    public Task DisposeAsync() => _postgres.DisposeAsync().AsTask();

    [Fact]
    public async Task ConcurrentOverlappingCreatesOnlyGrantOneLicense()
    {
        var device = await SeedDeviceAsync();
        var now = Now;
        var request = new CreateLicenseRequest(device.Id, now.AddMinutes(-1), now.AddDays(30), "Regression test");
        var results = await Task.WhenAll(CreateLicenseAsync(request), CreateLicenseAsync(request));
        Assert.Single(results, result => result is CreatedResult);
        Assert.Single(results, result => result is ObjectResult { StatusCode: 409 });
        await using var db = CreateContext();
        Assert.Equal(1, await db.Licenses.CountAsync(value => value.DeviceId == device.Id));
    }

    [Fact]
    public async Task TransferAndCreateCannotBothLicenseDestination()
    {
        var source = await SeedDeviceAsync();
        var destination = await SeedDeviceAsync();
        var now = Now;
        var license = new DeviceLicense(Guid.NewGuid(), _tenantId, source.Id, now.AddDays(-1), now.AddDays(30), now);
        await using (var seed = CreateContext())
        {
            seed.Licenses.Add(license);
            await seed.SaveChangesAsync();
        }
        var results = await Task.WhenAll(TransferAsync(), CreateLicenseAsync(
            new CreateLicenseRequest(destination.Id, now.AddMinutes(-1), now.AddDays(30), "Competing create")));
        Assert.Single(results, result => result is ObjectResult { StatusCode: 409 });
        Assert.Single(results, result => result is ObjectResult { StatusCode: 200 or 201 });
        await using var verify = CreateContext();
        Assert.Equal(1, await verify.Licenses.CountAsync(value => value.DeviceId == destination.Id));

        async Task<ActionResult?> TransferAsync()
        {
            await using var db = CreateContext();
            await using var tx = await db.BeginTenantTransactionAsync(_tenantId);
            var result = await LicenseController(db).Transfer(_tenantId, license.Id,
                new TransferLicenseRequest(destination.Id, license.ConcurrencyToken, "Competing transfer"), CancellationToken.None);
            await tx.CommitAsync();
            return result.Result;
        }
    }

    [Fact]
    public async Task RenewalCannotOverlapFutureLicense()
    {
        var device = await SeedDeviceAsync();
        var now = Now;
        var first = new DeviceLicense(Guid.NewGuid(), _tenantId, device.Id, now.AddDays(-1), now.AddDays(1), now);
        await using (var seed = CreateContext())
        {
            seed.Licenses.AddRange(first, new DeviceLicense(Guid.NewGuid(), _tenantId, device.Id, now.AddDays(1), now.AddDays(3), now));
            await seed.SaveChangesAsync();
        }

        await using (var db = CreateContext())
        {
            await using var tx = await db.BeginTenantTransactionAsync(_tenantId);
            var result = await LicenseController(db).Renew(_tenantId, first.Id,
                new RenewLicenseRequest(now.AddDays(2), first.ConcurrencyToken, "Regression renewal"), CancellationToken.None);
            Assert.IsType<ObjectResult>(result);
            Assert.Equal(409, ((ObjectResult)result).StatusCode);
            await tx.CommitAsync();
        }
        await using var verify = CreateContext();
        var persisted = await verify.Licenses.SingleAsync(value => value.Id == first.Id);
        Assert.Equal(first.ExpiresAtUtc.ToUnixTimeMilliseconds(), persisted.ExpiresAtUtc.ToUnixTimeMilliseconds());
    }

    [Fact]
    public async Task CompilationIsIdempotentAfterMembershipReentryAndVersionsSerialize()
    {
        var device = await SeedDeviceAsync();
        var now = Now;
        now = now.AddTicks(-(now.Ticks % TimeSpan.TicksPerMillisecond));
        var group = new DeviceGroup(Guid.NewGuid(), _tenantId, "Screens", null, _actorId, now);
        var playlist = new Playlist(Guid.NewGuid(), _tenantId, "Test", null, _actorId, now);
        var version = new PlaylistVersion(Guid.NewGuid(), _tenantId, playlist.Id, 1, "Test", null, _actorId, now);
        var content = new ContentAsset(Guid.NewGuid(), _tenantId, "Image", MediaKind.Png, _actorId, now);
        var contentVersion = new ContentVersion(Guid.NewGuid(), _tenantId, content.Id, 1, "test/image", 8,
            new byte[32], "image/png", "image.png", "{}", _actorId, now);
        content.Approve(now);
        contentVersion.RecordScanOutcome(ContentScanOutcome.Clean, "test", null);
        contentVersion.Approve(_actorId, now);
        version.Publish(_actorId, now);
        var assignment = new GroupAssignment(Guid.NewGuid(), _tenantId, group.Id, version.Id, 0, null, null, "UTC", _actorId, now);
        var second = new GroupAssignment(Guid.NewGuid(), _tenantId, group.Id, version.Id, 1, null, null, "UTC", _actorId, now);
        await using (var seed = CreateContext())
        {
            seed.AddRange(group, playlist, version, content, contentVersion, assignment, second,
                new PlaylistItem(Guid.NewGuid(), _tenantId, version.Id, contentVersion.Id, 0, 1000, false, "{}"),
                new DeviceGroupMember(Guid.NewGuid(), _tenantId, group.Id, device.Id, _actorId, now));
            await seed.SaveChangesAsync();
        }
        DesiredStateManifestAsset[] assets = [new(contentVersion.Id, 0, MediaKind.Png, 8, new byte[32], 1000, false, "{}")];
        var states = await Task.WhenAll(CompileAsync(assignment), CompileAsync(second));
        Assert.Equal(2, states.Select(value => value.Version).Distinct().Count());
        var reentered = await CompileAsync(assignment);
        Assert.Equal(states[0].Id, reentered.Id);
        await using var verify = CreateContext();
        Assert.Equal(2, await verify.DesiredStates.CountAsync(value => value.DeviceId == device.Id));
        var removed = await ReplaceMembersAsync([], group.ConcurrencyToken);
        var restored = await ReplaceMembersAsync([device.Id], removed.ConcurrencyToken);
        Assert.Equal(2, await verify.DesiredStates.CountAsync(value => value.DeviceId == device.Id));
        Assert.NotNull(await new DesiredStateResolver(verify).ResolveAsync(device.Id, Now, CancellationToken.None));
        await using (var archive = CreateContext())
        {
            var asset = await archive.ContentAssets.SingleAsync(value => value.Id == content.Id);
            asset.Archive(Now);
            await archive.SaveChangesAsync();
        }
        await ReplaceMembersAsync([], restored.ConcurrencyToken);
        Assert.Null(await new DesiredStateResolver(verify).ResolveAsync(device.Id, Now, CancellationToken.None));

        async Task<DeviceGroupResponse> ReplaceMembersAsync(Guid[] members, Guid concurrencyToken)
        {
            await using var db = CreateContext();
            await using var tx = await db.BeginTenantTransactionAsync(_tenantId);
            var controller = new DeviceGroupsController(db, new DesiredStateCompilationService(db), TimeProvider.System)
            {
                ControllerContext = LicenseController(db).ControllerContext
            };
            var result = await controller.ReplaceMembers(_tenantId, group.Id,
                new ReplaceDeviceGroupMembersRequest(members, concurrencyToken), CancellationToken.None);
            var response = Assert.IsType<DeviceGroupResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
            await tx.CommitAsync();
            return response;
        }

        async Task<DesiredState> CompileAsync(GroupAssignment source)
        {
            await using var db = CreateContext();
            await using var tx = await db.BeginTenantTransactionAsync(_tenantId);
            var state = await new DesiredStateCompilationService(db).CompileGroupAssignmentAsync(
                _tenantId, device.Id, source, assets, CancellationToken.None);
            await db.SaveChangesAsync();
            await tx.CommitAsync();
            return state;
        }
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task ResultIsExecutedOnlyAfterCommitIncludingRejectedAttemptEvidence(bool rejected)
    {
        await using var db = CreateContext();
        var device = new Device(Guid.NewGuid(), _tenantId, "Commit evidence", Now);
        var http = new DefaultHttpContext();
        http.SetEndpoint(new Endpoint(null, new EndpointMetadataCollection(new ControllerActionDescriptor()), "test"));
        var resultExecuted = false;
        var middleware = new TenantTransactionMiddleware(HandleRequest);
        async Task HandleRequest(HttpContext context)
        {
            db.Devices.Add(device);
            await db.SaveChangesAsync();
            IActionResult result = rejected ? new BadRequestResult() : new OkResult();
            var action = new ActionContext(context, new RouteData(), new ActionDescriptor());
            var filterContext = new ResultExecutingContext(action, [], result, new object());
            await new TenantTransactionCommitFilter().OnResultExecutionAsync(filterContext, async () =>
            {
                await using var other = CreateContext();
                Assert.True(await other.Devices.AnyAsync(value => value.Id == device.Id));
                resultExecuted = true;
                return new ResultExecutedContext(action, [], result, new object());
            });
        }
        await middleware.InvokeAsync(http, TenantContext(), db);
        Assert.True(resultExecuted);
    }

    [Fact]
    public async Task AuthenticatedStaticFallbackDoesNotOpenTenantTransaction()
    {
        await using var db = CreateContext();
        var http = new DefaultHttpContext();
        http.SetEndpoint(new Endpoint(null, new EndpointMetadataCollection(), "SPA fallback"));
        var executed = false;
        var middleware = new TenantTransactionMiddleware(_ =>
        {
            Assert.Null(db.Database.CurrentTransaction);
            executed = true;
            return Task.CompletedTask;
        });
        await middleware.InvokeAsync(http, TenantContext(), db);
        Assert.True(executed);
    }

    [Fact]
    public async Task CommitFailureDoesNotExecuteSuccessResult()
    {
        await using var db = CreateContext();
        var http = new DefaultHttpContext();
        http.SetEndpoint(new Endpoint(null, new EndpointMetadataCollection(new ControllerActionDescriptor()), "test"));
        var resultExecuted = false;
        var middleware = new TenantTransactionMiddleware(HandleRequest);
        async Task HandleRequest(HttpContext context)
        {
            await db.Database.ExecuteSqlRawAsync("CREATE TEMP TABLE commit_parent (id int PRIMARY KEY); CREATE TEMP TABLE commit_child (id int REFERENCES commit_parent(id) DEFERRABLE INITIALLY DEFERRED); INSERT INTO commit_child VALUES (1);");
            var action = new ActionContext(context, new RouteData(), new ActionDescriptor());
            var result = new OkResult();
            await new TenantTransactionCommitFilter().OnResultExecutionAsync(
                new ResultExecutingContext(action, [], result, new object()), () =>
                {
                    resultExecuted = true;
                    return Task.FromResult(new ResultExecutedContext(action, [], result, new object()));
                });
        }
        var exception = await Assert.ThrowsAsync<PostgresException>(() => middleware.InvokeAsync(http, TenantContext(), db));
        Assert.Equal(PostgresErrorCodes.ForeignKeyViolation, exception.SqlState);
        Assert.False(resultExecuted);
        Assert.False(http.Response.HasStarted);
    }

    private async Task<Device> SeedDeviceAsync()
    {
        var now = Now;
        var device = new Device(Guid.NewGuid(), _tenantId, "Regression screen", now);
        device.CompleteEnrollment(Guid.NewGuid().ToString("N"), "screen", "Linux", "arm64", "test", "test", 4096, now);
        await using var db = CreateContext();
        db.Devices.Add(device);
        await db.SaveChangesAsync();
        return device;
    }

    private async Task<ActionResult?> CreateLicenseAsync(CreateLicenseRequest request)
    {
        await using var db = CreateContext();
        await using var tx = await db.BeginTenantTransactionAsync(_tenantId);
        var result = await LicenseController(db).Create(_tenantId, request, CancellationToken.None);
        await tx.CommitAsync();
        return result.Result;
    }

    private LicensesController LicenseController(DisplayControlDbContext db) => new(db, TimeProvider.System)
    {
        ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, _actorId.ToString())], "test"))
            }
        }
    };

    private ScopedTenantContext TenantContext()
    {
        var tenant = new ScopedTenantContext();
        tenant.SetFromTrustedBoundary(_tenantId);
        return tenant;
    }

    private DisplayControlDbContext CreateContext() => new(
        new DbContextOptionsBuilder<DisplayControlDbContext>().UseNpgsql(_postgres.GetConnectionString()).Options,
        TenantContext());
}
