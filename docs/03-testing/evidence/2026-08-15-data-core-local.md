# Local Data-Core Verification — 2026-08-15

## Evidence status

This is evidence from an uncommitted Windows development tree, not a release attestation. The PostgreSQL isolation boundary is locally proven on the exact pinned image. Remote CI, production object storage, certificate transport and real Raspberry Pi hardware remain open.

## Implemented slice

- Ten EF migrations define tenants, devices, licences, immutable media/version data, playlists, assignments, desired state, device identity and telemetry, human IAM, MFA/recovery replay guards and a protected notification queue.
- The tenant row plus 24 tables carrying tenant scope have `ENABLE ROW LEVEL SECURITY`, `FORCE ROW LEVEL SECURITY` and fail-closed policies.
- Same-tenant composite foreign keys protect device, licence, media, playlist, assignment, desired-state, group, certificate, enrollment and telemetry relations.
- The runtime role is non-owner, non-superuser and has no `BYPASSRLS`. Its grants are lifecycle-specific. It can insert encrypted identity notifications but cannot read them back.
- The private object-store contract uses GUID-only keys. Its local-only adapter enforces an absolute private root, reparse-point checks, exact bounded lengths, atomic publication and no overwrite.

## Passed checks

| Check | Actual result |
|---|---|
| Debug .NET build | Passed, 0 warnings, 0 errors |
| Complete .NET test run | 48 passed: 23 domain, 4 agent, 21 integration; 0 failed, 0 skipped |
| PostgreSQL boundary | Exact `postgres:18.4-alpine3.24` image under Docker Engine 29.6.1 |
| Restricted-role RLS | Passed: role attributes, 25 protected tables, missing context, tenant A/B reads, rejected cross-tenant insert and pool reset |
| IAM HTTP integration | Passed: password failure, MFA enrollment, ten unique recovery codes, RBAC, cross-tenant denial and sign-out |
| Migration policy test | Passed; model-derived tenant table inventory exactly matched the policy inventory |
| EF pending-model check | No changes since latest migration |
| Idempotent SQL generation | Passed; 74,625 bytes; SHA-256 `56CCE6CD32E9330C674A3D0079AEB56CA663BBC899E58822B0746F60263E630C` |
| SQL policy inspection | 25 tenant-isolation policies |
| `dotnet format --verify-no-changes` | Passed |
| NuGet scan including transitives | No vulnerable package reported |
| npm audit including development packages | 0 vulnerabilities |
| React lint/typecheck/tests/build | Passed; 4 Vitest tests and both production bundles |

## Explicit gaps

- Remote CI and commit-bound evidence do not yet exist because no remote repository is configured.
- The filesystem object store is not a production adapter and has not been represented as one.
- Password-reset payloads are protected and queued, but no external delivery worker/provider is implemented yet.
- Certificate issuance, mTLS handshake/rotation/revocation and enrollment consumption are modeled but not yet proven.
- No physical Raspberry Pi, browser-kiosk, outage-soak, backup/restore or production deployment evidence is claimed.
