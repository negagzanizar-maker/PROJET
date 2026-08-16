# Secure Vertical Slice — Local Evidence — 2026-08-15

## Scope

This bundle records reproducible local evidence for the implemented vertical slice. It supersedes earlier test-count snapshots but does not rewrite them. It is not production, remote-CI, live-backend browser-E2E, or physical-hardware evidence.

## Verified results

| Boundary | Command/check | Result |
|---|---|---|
| .NET formatting | `dotnet format DisplayControl.slnx --verify-no-changes --no-restore` | Passed |
| Domain rules | `dotnet test tests/DisplayControl.Domain.Tests --no-restore` | 44 passed |
| Pi agent | `dotnet test tests/DisplayControl.DeviceAgent.Tests --no-restore` | 10 passed |
| API/PostgreSQL/security integration | `dotnet test tests/DisplayControl.IntegrationTests --no-restore` | 30 passed |
| React component behavior | `npm test` | 7 passed: 4 administration, 3 player |
| Real-browser UI and accessibility boundary | `npm run test:e2e` with Playwright 1.61.1, axe 4.12.1 and installed Chrome 151.0.7922.76 | 5 passed: CSRF sign-in, enumeration-safe recovery, one-use invitation, fail-closed player and manifest text playback; covered views have zero axe WCAG A/AA violations |
| React static checks | `npm run lint` and `npm run typecheck` | Passed |
| Production web bundles | `npm run build` | Passed; administration and player bundles emitted |
| EF migration/model drift | `dotnet ef migrations has-pending-model-changes` | Passed; no pending model changes |
| PostgreSQL security boundary | Restricted-role integration suite on `postgres:18.4-alpine3.24` | Passed; 25 forced-RLS tables, 28 policies and tenant isolation exercised |
| Real TLS/mTLS listener | Real loopback Kestrel HTTPS listener using optional client certificates and the production device-certificate middleware | Enrolled active certificate 200; missing certificate 401; untrusted certificate 401 |
| Generated deployment SQL | `deploy/postgres/schema.idempotent.sql` | 78,675 bytes; SHA-256 `924B06B9D912F994339482281A3F6D8CF172D51303EAA63EE9512D132441F76E`; latest migration and all 28 policies present |
| NuGet vulnerability check | `dotnet list DisplayControl.slnx package --vulnerable --include-transitive` | No vulnerable packages reported |
| npm vulnerability check | `npm audit --audit-level=high` | 0 vulnerabilities reported |
| Compose validation | `docker compose --env-file .env.example config --quiet` | Passed |
| Documentation | `& ./scripts/verify-docs.ps1` from the local PowerShell session | Passed: 34 Markdown files, 265 unique requirements, exact traceability coverage and zero broken local links |

## Security-relevant scenarios exercised

- invitation-only authentication, password failure, MFA enrollment/confirmation and recent-MFA step-up, recovery codes, session revocation, CSRF/RBAC and cross-tenant denial;
- database rejection with missing tenant context, tenant A/B isolation, rejected cross-tenant writes and pooled-connection context reset;
- one-use enrollment, serial binding, duplicate identity quarantine, certificate issuance, certificate rotation and revocation state, exact safe replay after a lost enrollment/rotation response, and rejection when the retry changes its public key;
- licence boundaries, renewal/suspension/reactivation/revocation, atomic transfer, bounded signed lease and device/certificate/state binding;
- file signature/type/size inspection, fail-closed scanner behavior, explicit approval, immutable private storage and manifest-scoped asset authorization;
- immutable playlist publication, direct-device and multi-group assignment, `[start,end)` UTC schedules, direct-over-group precedence, priority/conflict handling, canonical manifest hashing and heartbeat delivery;
- agent state/key crash recovery, corrupt content rejection, validated byte-range resume after an interrupted transfer, verified atomic cache activation and player fail-closed states;
- real local Kestrel TLS negotiation with the same device authentication middleware used by the API;
- packaged React administration shell and local player assets with restrictive Content Security Policy.

## Explicitly not proved by this bundle

- no remote CI run or signed release artifact;
- no deployed production edge/proxy TLS topology test; the local real-Kestrel client-certificate handshake is proved above;
- no physical Raspberry Pi 4/5, Chromium hardware-decoding, monitor, reboot, disk-pressure or long outage evidence;
- no external email/SMS delivery, production DNS/TLS/secrets service, monitoring/alerting, backup restore or disaster-recovery exercise;
- no complete Playwright journey against a live API/PostgreSQL stack, manual assistive-technology audit, load/soak campaign, penetration test or full ASVS close-out; the five deterministic browser/axe checks above prove only their listed views and request boundaries;
- no proof yet for general human-command idempotency, multi-node object storage or signed agent update rollback.

These items remain open release gates in the roadmap; none is inferred from unit or test-host success.
