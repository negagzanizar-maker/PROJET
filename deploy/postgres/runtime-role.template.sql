\set ON_ERROR_STOP on

-- Execute as the schema owner after migrations. Supply a validated identifier:
-- psql --set=runtime_role=display_control_runtime --file runtime-role.template.sql
-- Authentication/login credentials are provisioned by the deployment secret manager,
-- never embedded in this repository.

\if :{?runtime_role}
\else
\echo 'runtime_role variable is required'
\quit
\endif

SELECT format(
    'CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS',
    :'runtime_role')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'runtime_role')
\gexec

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA app TO :"runtime_role";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO :"runtime_role";

GRANT SELECT ON
    app.identity_role_claims,
    app.identity_roles,
    app.system_key_metadata
TO :"runtime_role";

-- Tenant lifecycle mutations remain protected by recent-MFA platform authorization and audit.
GRANT SELECT, INSERT, UPDATE ON app.tenants TO :"runtime_role";

-- Append-only operational and licensing evidence.
GRANT SELECT, INSERT ON
    app.audit_events,
    app.device_heartbeats,
    app.device_synchronization_events,
    app.license_events
TO :"runtime_role";

-- Mutable only through archive/retire/revoke/version transitions; no hard delete.
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
    app.playlist_versions,
    app.playlists,
    app.tenant_memberships
TO :"runtime_role";

-- Draft/membership/work-queue rows have controlled deletion workflows.
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
TO :"runtime_role";

-- The web runtime may enqueue protected notifications but cannot read them back.
-- A future delivery worker receives a separate, narrowly scoped database role.
GRANT INSERT ON app.identity_notifications TO :"runtime_role";

REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA app FROM :"runtime_role";
ALTER DEFAULT PRIVILEGES IN SCHEMA app REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA app REVOKE ALL ON SEQUENCES FROM PUBLIC;
