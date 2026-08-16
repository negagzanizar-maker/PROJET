using DisplayControl.Domain.Scheduling;
using DisplayControl.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace DisplayControl.Api.Scheduling;

public sealed class DesiredStateResolver(DisplayControlDbContext dbContext)
{
    public async Task<DesiredState?> ResolveAsync(
        Guid deviceId,
        DateTimeOffset nowUtc,
        CancellationToken cancellationToken)
    {
        AssignmentSchedule.EnsureUtc(nowUtc, nameof(nowUtc));
        var direct = await (
            from state in dbContext.DesiredStates.AsNoTracking()
            join assignment in dbContext.DeviceAssignments.AsNoTracking()
                on state.SourceDeviceAssignmentId equals (Guid?)assignment.Id
            where state.DeviceId == deviceId && state.SupersededByDesiredStateId == null &&
                assignment.IsEnabled &&
                (assignment.StartsAtUtc == null || assignment.StartsAtUtc <= nowUtc) &&
                (assignment.EndsAtUtc == null || assignment.EndsAtUtc > nowUtc)
            orderby assignment.Priority descending, assignment.PublishedAtUtc descending, assignment.Id
            select new DesiredStateCandidate(state, assignment.Priority))
            .Take(2)
            .ToListAsync(cancellationToken);
        var directWinner = SelectUnambiguous(direct, "direct-device");
        if (directWinner is not null)
        {
            return directWinner;
        }

        var group = await (
            from state in dbContext.DesiredStates.AsNoTracking()
            join assignment in dbContext.GroupAssignments.AsNoTracking()
                on state.SourceGroupAssignmentId equals (Guid?)assignment.Id
            join membership in dbContext.DeviceGroupMembers.AsNoTracking()
                on new { assignment.TenantId, assignment.DeviceGroupId, DeviceId = state.DeviceId }
                equals new { membership.TenantId, membership.DeviceGroupId, membership.DeviceId }
            where state.DeviceId == deviceId && state.SupersededByDesiredStateId == null &&
                assignment.IsEnabled &&
                (assignment.StartsAtUtc == null || assignment.StartsAtUtc <= nowUtc) &&
                (assignment.EndsAtUtc == null || assignment.EndsAtUtc > nowUtc)
            orderby assignment.Priority descending, assignment.PublishedAtUtc descending, assignment.Id
            select new DesiredStateCandidate(state, assignment.Priority))
            .Take(2)
            .ToListAsync(cancellationToken);
        return SelectUnambiguous(group, "group");
    }

    private static DesiredState? SelectUnambiguous(
        IReadOnlyList<DesiredStateCandidate> candidates,
        string targetClass)
    {
        if (candidates.Count > 1 && candidates[0].Priority == candidates[1].Priority)
        {
            throw new InvalidOperationException($"Ambiguous active {targetClass} assignment state was detected.");
        }

        return candidates.Count == 0 ? null : candidates[0].State;
    }

    private sealed record DesiredStateCandidate(DesiredState State, int Priority);
}
