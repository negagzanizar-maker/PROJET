# Audit remediation — 7 September 2026

The application has a sound modular foundation and meaningful tenant/security boundaries. This remediation addresses confirmed correctness and usability defects. It does not establish that every possible defect is absent or that production acceptance is complete.

## Implemented fixes

| Area | Change |
|---|---|
| Human security | Content Managers require MFA; MFA rotates the session lookup credential without extending its lifetime; clients refresh CSRF/session state; account session listing and revocation are available. |
| Licensing | Transferred licences cannot be reactivated; outstanding lease expiry keeps the maximum issued boundary; per-device transaction locks serialize licence changes and heartbeat issuance; overlapping creation, renewal and transfer destinations are checked. |
| Scheduling | Tenant transaction locks serialize compilation/version allocation; group re-addition supersedes old membership work; archived content is removed from groups; ambiguous desired state fails closed. |
| Transactions | MVC tenant transactions commit before result execution, including streamed results. Returned authentication failures still persist their audit/lockout evidence. |
| Administration | Paged collection traversal, real playlist counts, explicit UTC entry, ordered multi-item drafts with retryable publication, recovery-code login, session controls, mobile/role navigation and clearer request failures. |
| Playback | Unchanged manifests retain playback identity; authorized cached playback remains available while replacement content stages; synchronization attempts have a deadline; polling is serialized; playback errors and successful text playback report telemetry. |
| Device operations | Health reports freshness and release identity; authenticated heartbeat responses distribute a bounded validated signing-key set; installer restarts the agent and checks the selected release before accepting activation, with documented rollback limits. |
| Retention | Workers can drain multiple bounded batches rather than one batch per interval. A 30-second elapsed-time check prevents starting further batches indefinitely; an in-progress SQL command may finish after that boundary. |
| Release tooling | A local publish script builds web assets first and verifies both published entry points; publish targets reject missing assets; CI checks both outputs and each Linux script separately. |

## Verification

- Release solution build passed with zero warnings/errors.
- Domain tests: 47 passed. Device-agent tests: 17 passed.
- Full PostgreSQL-backed integration run: 53 passed. The subsequently expanded backend suite passed 7 focused cases; both authentication scenarios passed again after adding session-revocation coverage. One interim authentication test incorrectly expected a successful response for a revoked cookie; the corrected assertion verifies the intended 401 response.
- Admin tests: 9 passed. Player tests: 5 passed. Playwright/axe browser tests: 7 passed.
- Both production web builds, lint and TypeScript checks passed.
- Both hosts published successfully with `wwwroot/index.html` present.
- EF reported no pending model changes. PowerShell syntax and documentation link/traceability checks passed; Pi installer Bash syntax passed.

The first database test attempt failed during Docker initialization. Docker was then started and the full integration run passed. Browser tests use intercepted API responses; they are not deployed-service end-to-end evidence.

## Remaining acceptance and improvement work

| Priority | Work still required | Evidence needed |
|---|---|---|
| Before production | Physical Raspberry Pi playback, power/network interruption, disk pressure, activation and rollback | Recorded field-test results on supported hardware; follow the Pi provisioning runbook. |
| Before production | Deployed-service browser acceptance, backup/restore, monitoring and production security configuration | A staging run with real services and operational recovery evidence. |
| Before production at scale | Fleet load and retention capacity, group compilation fan-out, heartbeat write volume and query/index selection | Representative load measurements and database query plans. No fleet capacity claim is made. |
| Deployment design | Independently signed update metadata | Installer currently checks a supplied SHA-256 digest; that does not provide an independent publisher signature. |
| Improvement | Server-filtered/on-demand dashboard pages and per-feature mutation state | Current dashboard still eagerly traverses bounded pages; shared busy/error state remains. Offset cursors are not snapshot pagination. |
| Improvement | Deeper media decoding validation and additional adversarial fixtures | Header inspection and malware scanning do not prove every media stream is decodable. |
| Improvement | Broader live browser coverage, smaller authentication test scenarios and generated API-client compatibility checks | Current tests cover concrete regressions but do not cover all workflows or failure combinations. |

No production deployment, database reset, or physical-device acceptance was performed. Existing report documents and unrelated staged files were preserved.
