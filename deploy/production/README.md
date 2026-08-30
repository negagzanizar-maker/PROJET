# Single-node production deployment baseline

This directory hardens the supported single-node topology. It does not turn unresolved provider choices or missing staging evidence into completed work. The API deliberately refuses `Deployment__InstanceCount` values other than `1`; a multi-node deployment requires shared private object storage, distributed rate limiting, and reviewed worker coordination.

## Required external services

- Linux host with public DNS and a publicly trusted TLS certificate for every value in `AllowedHosts`.
- PostgreSQL 18 reachable through certificate-verified TLS.
- ClamAV reachable only from the API network.
- Encrypted persistent volumes for content and Data Protection keys.
- Secret manager for database credentials, token pepper, TLS certificate password, device CA, Data Protection encryption certificate, and licence-signing key.
- Central journal/log collection, metrics/alerts, off-host encrypted backup storage, and a tested recovery environment.
- SMTP provider when notification delivery is enabled.

## Database provisioning

1. Apply `deploy/postgres/schema.idempotent.sql` as the migration owner.
2. Provision login identities separately through the secret manager.
3. Grant the web login membership in the role created by `runtime-role.template.sql`.
4. If enabled, provision the notification and maintenance identities using their dedicated templates.
5. Connect as the exact web runtime login and run `verify-runtime-security.sql`. Do not start the API if it fails.

The migration owner must never be used by the running application. The web runtime must not be superuser, `BYPASSRLS`, an application-table owner, or able to read protected notification payloads.

## Host installation

1. Create the non-login `display-control-api` user and group.
2. Publish the API for the target Linux runtime from the exact tested commit and install it read-only under `/opt/display-control/api`.
3. Create `/var/lib/display-control/content` and `/var/lib/display-control/data-protection`, owned only by `display-control-api` with mode `0700`.
4. Install secret-manager material read-only under `/etc/display-control/secrets`.
5. Copy `api.env.example` to `/etc/display-control/api.env`, replace every placeholder, set mode `0600`, and allow the service group to read it.
6. Install `display-control-api.service`, run `systemd-analyze verify`, reload systemd, and enable the service.

Production startup rejects wildcard hosts, unverified PostgreSQL TLS, missing key files, overlapping content/key paths, missing public TLS configuration, and an invalid Data Protection encryption certificate. Readiness also rejects a superuser or `BYPASSRLS` database identity.

## Backup and restore

`offline-backup.sh` deliberately refuses to run while the API service is active. This keeps PostgreSQL metadata, private media, and Data Protection keys from changing during capture. Store the resulting archive and checksum off-host using encryption and immutability controls.

`verify-backup.sh` checks the archive hashes and formats. Release acceptance still requires an isolated restore drill:

1. create an empty recovery PostgreSQL instance;
2. restore `database.dump` using `pg_restore`;
3. restore media and Data Protection keys to empty dedicated directories;
4. restore the separately protected CA/signing/encryption keys and secrets;
5. start the exact release in the recovery environment;
6. prove tenant isolation, login/session behavior, manifest hashes, media delivery, and licence expiry;
7. record recovery time, recovery point, commands, tester, commit, and evidence hashes.

## Release gate

Before public production use, retain evidence for a real SMTP test, live browser-to-API-to-PostgreSQL E2E, expected-fleet load, network/storage/scanner faults, backup restoration, vulnerability scanning, and an independent security review. Physical Pi acceptance remains a separate hardware gate.
