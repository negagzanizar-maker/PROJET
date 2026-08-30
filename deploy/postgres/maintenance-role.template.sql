\set ON_ERROR_STOP on

-- Execute as schema owner after migrations. Authentication for this fixed-purpose login
-- is provisioned by the deployment secret manager and never stored in this repository.
SELECT 'CREATE ROLE display_control_maintenance LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'display_control_maintenance')
\gexec

GRANT USAGE ON SCHEMA app TO display_control_maintenance;
GRANT SELECT, DELETE ON app.device_heartbeats, app.audit_events TO display_control_maintenance;
REVOKE INSERT, UPDATE, TRUNCATE, REFERENCES, TRIGGER
    ON app.device_heartbeats, app.audit_events
    FROM display_control_maintenance;
