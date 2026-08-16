\set ON_ERROR_STOP on

-- Execute as schema owner after migrations. The login that receives this role is supplied
-- to ConnectionStrings__NotificationDatabase through the deployment secret manager.
\if :{?notification_role}
\else
\echo 'notification_role variable is required'
\quit
\endif

SELECT format(
    'CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS',
    :'notification_role')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'notification_role')
\gexec

GRANT USAGE ON SCHEMA app TO :"notification_role";
GRANT SELECT, UPDATE ON app.identity_notifications TO :"notification_role";
REVOKE TRUNCATE, REFERENCES, TRIGGER ON app.identity_notifications FROM :"notification_role";
