# PostgreSQL Security Baseline

## Roles

- The schema owner/migration identity owns objects and is unavailable to normal application requests.
- The runtime identity is not a table owner, superuser, member of an owner role, or holder of `BYPASSRLS`; it cannot create in trusted schemas, alter policies, truncate tables, or change roles.
- Backup and monitoring identities will be separate and documented before production.

`deploy/postgres/runtime-role.template.sql` creates the non-login permission role without embedding credentials. A deployment-specific login identity may receive that role through the external secret/provisioning process.

## Tenant context

Tenant-owned transactions set `app.tenant_id` using PostgreSQL `set_config(..., true)`. The third argument makes the value transaction-local, preventing a pooled connection from retaining another tenant after commit/rollback. The value must come from authenticated server context; route/query/body values remain untrusted selectors.

Tenant-owned business tables use:

- non-null `tenant_id`;
- same-tenant composite foreign keys where applicable;
- application query filters as defense in depth;
- `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY`;
- one explicit `USING` and `WITH CHECK` policy; and
- default denial when `app.tenant_id` is absent.

`identity_notifications` is the narrow exception because a platform administrator has no tenant. It still has forced RLS: tenant notifications require the matching transaction context, while a `NULL` tenant is accepted only with no tenant context. The web runtime has `INSERT` only on this table and therefore cannot retrieve protected reset payloads. Delivery will use a separate worker identity with explicitly reviewed grants.

Superusers and roles explicitly granted `BYPASSRLS` can bypass policies; neither is permitted for the web runtime identity. `FORCE ROW LEVEL SECURITY` also subjects the table owner during ordinary queries, although the migration owner can alter the schema and policies and therefore remains a separately controlled deployment identity. Integration tests inspect catalog flags, role attributes, missing context, cross-tenant reads/writes and connection-pool reuse using a genuinely restricted role.

## Migration rule

Generated EF migrations are reviewed before execution. RLS SQL, grants, destructive changes and lock behavior receive manual review. Production migration and application startup are separate operations; the web process does not auto-migrate with owner credentials.
