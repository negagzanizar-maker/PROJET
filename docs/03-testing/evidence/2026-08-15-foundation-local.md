# Local Foundation Verification — 2026-08-15

## Evidence status

This is a provisional local-development record, not immutable release evidence. The workspace does not yet have a release commit or remote CI run. Results must be repeated and hashed against a commit before they can support final `Verified` traceability status.

## Environment

| Component | Observed value |
|---|---|
| Host | Windows 10.0.26200, x64 |
| .NET SDK | 10.0.203 |
| .NET runtime | 10.0.7 |
| Node.js | 25.6.1 |
| npm | 11.9.0 |
| Docker client/engine | 29.6.1 |
| Date | 2026-08-15, Africa/Casablanca |
| Source identity | Uncommitted working tree; unsuitable for release attestation |

## Passed checks

| Check | Actual result |
|---|---|
| `dotnet restore DisplayControl.slnx --locked-mode` | Passed after lock generation |
| `dotnet build ... --configuration Release --no-restore` | Passed, 0 warnings, 0 errors |
| Non-container .NET tests | 12 passed, 0 failed, 0 skipped |
| `dotnet format ... --verify-no-changes` | Passed |
| NuGet vulnerable package scan including transitives | No vulnerable package reported |
| npm audit, including development dependencies | 0 vulnerabilities |
| React lint | Both workspaces passed |
| TypeScript build-mode type check | Both workspaces passed |
| Vitest | 3 passed, 0 failed, 0 skipped |
| Vite production build | Both workspaces passed |
| Documentation verifier | Passed; unique requirement IDs, exact CSV coverage, no broken local link |
| Compose configuration | Parsed successfully with synthetic environment variables |
| EF pending-model check | No changes since latest migration |
| Idempotent migration script inspection | Forced RLS and tenant policies present for devices, licences, audit and outbox |

## Security finding resolved during the gate

The first NuGet restore found high-severity advisory `GHSA-v5pm-xwqc-g5wc` in transitive `Microsoft.OpenApi` 2.0.0. The dependency was centrally pinned to patched 2.11.0, lock files were regenerated, and the transitive vulnerability scan then returned no vulnerable package. This is useful evidence that warnings-as-errors and package auditing are active controls.

## Not yet executed or not yet sufficient

- The official `postgres:18.4-alpine3.24` image did not finish downloading from Docker Hub within the bounded local attempts. No PostgreSQL 16 substitution was accepted.
- `PostgreSqlRlsTests` is compiled but was excluded from the passing local count. It still must prove real PostgreSQL 18 catalog flags, restricted role attributes, missing-context denial, cross-tenant denial, `WITH CHECK`, and pooled-connection reset.
- GitHub Actions is configured with read-only permissions and immutable action SHAs but cannot be claimed as executed until a remote repository runs it.
- No Raspberry Pi, mTLS, browser E2E, backup/restore, load, or production-equivalent evidence exists yet.

These gaps keep the relevant traceability rows at `Specified` and keep the engineering/data gates open.
