# Production-readiness hardening evidence — 2026-08-30

This record captures the local software evidence produced before the physical Raspberry Pi field test. It does not claim that external production acceptance is complete.

## Successful local gates

| Gate | Result |
| --- | --- |
| Release build | Passed with zero warnings and zero errors |
| .NET tests | 102/102: 44 domain, 12 agent, 46 integration |
| React tests | 8/8: 4 administration, 4 player |
| Playwright/axe | 5/5 browser scenarios passed |
| Static frontend gates | lint, TypeScript and both Vite production builds passed |
| Dependency audit | no known vulnerable NuGet or production npm dependency reported |
| Drift and quality | .NET formatting and EF Core pending-model check passed |
| Repository checks | 38 Markdown files, 265 requirements, exact traceability, no broken local links |
| Deployment syntax | PowerShell, Linux shell and Compose configuration passed |

On Windows, Linux script validation used the installed Git Bash executable because the registered WSL launcher has no Linux distribution. CI uses Ubuntu and runs the same scripts with native Bash.

## Raspberry Pi artifact

- Version: `0.1.5-field-test`
- Target: self-contained `.NET 10` `linux-arm64`
- Entries: 362
- Required files: `DisplayControl.DeviceAgent` and `wwwroot/index.html` present
- Forbidden credential/key filename scan: no `.env`, enrollment-code, PFX/P12, private-key or SSH-key file present
- SHA-256: `002d85a716882d206c70da680d3829a7ddec3244e6c4cbc21407f803db9c43d4`

## Production hardening covered

- Production startup rejects wildcard hosts, placeholder certificate/key passwords, unverified PostgreSQL TLS, missing security files and overlapping content/key directories.
- Persisted Data Protection keys are encrypted with a separate currently valid RSA certificate.
- Readiness rejects a superuser, `BYPASSRLS` role or owner of application tables; a standalone SQL deployment check verifies additional runtime privileges.
- Notification SMTP delivery has a bounded timeout and terminal failed-state behavior.
- Static hashed assets receive immutable cache headers; API and health responses remain `no-store` and carry a correlation identifier.
- A hardened single-node systemd unit, production environment template, coherent offline backup and backup-structure verifier are present.

## Gates that cannot be proven on this workstation

- Raspberry Pi 4/5 display, GPU/video/audio, serial/network inventory, reboot, power loss, disk pressure and long endurance.
- Public DNS/TLS and the chosen production host/provider.
- Real SMTP delivery, bounce/support behavior and alerts.
- Centralized logs, metrics and paging.
- Isolated backup restoration with measured RPO/RTO.
- Expected-fleet load/fault testing and an independent security review.
