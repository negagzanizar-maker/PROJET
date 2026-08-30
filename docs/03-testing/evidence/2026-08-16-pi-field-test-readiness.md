# Raspberry Pi field-test readiness evidence — refreshed 2026-08-30

## Scope

This workstation gate validates the deliverable prepared for a Raspberry Pi 4/5 field test. It does not claim physical display, hardware acceleration, power-loss or endurance evidence.

## Results

| Check | Result |
|---|---|
| Release solution build | Passed; zero warnings and zero errors |
| .NET tests | Passed; 88/88 (44 domain, 12 agent, 32 integration) |
| PostgreSQL boundary | Passed against real PostgreSQL 18; authentication and forced-RLS isolation included |
| React tests | Passed; 8/8 (4 administration, 4 player) |
| Device inventory path | Passed; hostname, hardware serial, interface name, local IP addresses and normalized MAC address flow through enrollment/API storage and render in the administration dashboard |
| Virtual device end-to-end | Passed on Windows; certificate enrollment, real host IP/MAC inventory, mTLS heartbeat, licence lease, desired state, text asset download and player state `ready` |
| Browser/accessibility | Passed; 5/5 Playwright/axe scenarios |
| Web lint, type-check and builds | Passed |
| Documentation verification | Passed; 265 requirements, exact traceability and zero broken local links |
| Dependency audit | No known NuGet or npm production vulnerability reported |
| ARM64 publication | Self-contained `linux-arm64` agent produced with embedded player Web assets |
| Pi archive inspection | Version `0.1.3-field-test`; 362 entries; expected executable and `wwwroot/index.html` present; no private key, PFX or enrollment secret included |
| Pi archive SHA-256 | `6cf4183ed67777bfc24b16f803c2c3f5add746dd40726642906bbc838f6efe38` |
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
