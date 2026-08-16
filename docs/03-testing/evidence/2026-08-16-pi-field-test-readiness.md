# Raspberry Pi field-test readiness evidence — 2026-08-16

## Scope

This workstation gate validates the deliverable prepared for a Raspberry Pi 4/5 field test. It does not claim physical display, hardware acceleration, power-loss or endurance evidence.

## Results

| Check | Result |
|---|---|
| Release solution build | Passed; zero warnings and zero errors |
| .NET tests | Passed; 84/84 (44 domain, 10 agent, 30 integration) |
| PostgreSQL boundary | Passed against real PostgreSQL 18; authentication and forced-RLS isolation included |
| React tests | Passed; 7/7 |
| Browser/accessibility | Passed; 5/5 Playwright/axe scenarios |
| Web lint, type-check and builds | Passed |
| Documentation verification | Passed; 265 requirements, exact traceability and zero broken local links |
| Dependency audit | No known NuGet or npm production vulnerability reported |
| ARM64 publication | Self-contained `linux-arm64` agent produced with embedded player Web assets |
| Pi archive inspection | 361 entries; expected executable and `wwwroot/index.html` present; no private key, PFX or enrollment secret included |
| Pi archive SHA-256 | `b7ad51af7de30c294137090c7ada1ac759de84a1e8bdf6e54660b7cfe30303d9` |
| Generated LAN HTTPS | Certificate generated for the supplied LAN address; health endpoint validated against its generated CA |
| Field server launcher | PostgreSQL and ClamAV healthy, all migrations applied, API started, health returned `healthy`, administration shell served |
| Compose isolation | Field-test project uses its own containers/volumes and PostgreSQL host port `55432`; unrelated `atlas-*` containers were not changed |
| Installer/script syntax | PowerShell parser and Git Bash `bash -n` passed |

## Live-start defects found and corrected

- PostgreSQL 18 volume target aligned to `/var/lib/postgresql`.
- The field-test Compose project was isolated from existing local stacks and the common host port `5432`.
- Native-command readiness probes were made safe under Windows PowerShell 5.1 error semantics.
- Physical `wwwroot` roots were added so Development static-asset discovery works with the embedded React builds.
- `UniformPasswordFailureService` was corrected from singleton to scoped lifetime to match ASP.NET Identity's password hasher.
- Wayland/X11 desktop attachment and local field-test CA installation were added to the Raspberry Pi installer.

## Remaining physical gate

Follow `docs/05-operations/FIELD_TEST_TOMORROW.md` on the target network and Raspberry Pi. Capture the real display, inventory, enrollment, playback, licence suspension/reactivation, offline interval and reboot evidence.
