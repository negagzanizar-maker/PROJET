\set ON_ERROR_STOP on

-- Run this through the exact ConnectionStrings__Database identity before starting the API.
DO $verification$
DECLARE
    role_is_unsafe boolean;
    owns_application_tables boolean;
    tenant_table_without_forced_rls boolean;
BEGIN
    SELECT rolsuper OR rolbypassrls
    INTO role_is_unsafe
    FROM pg_roles
    WHERE rolname = current_user;

    IF COALESCE(role_is_unsafe, true) THEN
        RAISE EXCEPTION 'Runtime role must not be superuser or BYPASSRLS';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_class AS relation
        JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = 'app'
          AND relation.relkind IN ('r', 'p')
          AND relation.relowner = (SELECT oid FROM pg_roles WHERE rolname = current_user)
    ) INTO owns_application_tables;

    IF owns_application_tables THEN
        RAISE EXCEPTION 'Runtime role must not own application tables';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_class AS relation
        JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
        JOIN information_schema.columns AS column_definition
          ON column_definition.table_schema = namespace.nspname
         AND column_definition.table_name = relation.relname
         AND column_definition.column_name = 'tenant_id'
        WHERE namespace.nspname = 'app'
          AND relation.relkind IN ('r', 'p')
          AND (NOT relation.relrowsecurity OR NOT relation.relforcerowsecurity)
    ) INTO tenant_table_without_forced_rls;

    IF tenant_table_without_forced_rls THEN
        RAISE EXCEPTION 'Every tenant table must have enabled and forced row-level security';
    END IF;

    IF has_table_privilege(current_user, 'app.identity_notifications', 'SELECT') THEN
        RAISE EXCEPTION 'Web runtime must not read protected notification payloads';
    END IF;

    IF has_table_privilege(current_user, 'app.audit_events', 'DELETE') OR
       has_table_privilege(current_user, 'app.device_heartbeats', 'DELETE') OR
       has_table_privilege(current_user, 'app.license_events', 'DELETE') THEN
        RAISE EXCEPTION 'Web runtime must not delete append-oriented operational evidence';
    END IF;
END
$verification$;

SELECT current_user AS verified_runtime_role,
       current_database() AS verified_database,
       current_setting('server_version') AS postgres_version;
