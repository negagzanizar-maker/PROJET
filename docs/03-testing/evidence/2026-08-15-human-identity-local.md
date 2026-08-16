# Local Human-Identity Verification — 2026-08-15

## Implemented controls

- Invitation-only user creation with opaque single-use capability tokens stored only as HMAC digests.
- ASP.NET Core Identity password hashing at 210,000 PBKDF2 iterations, confirmed unique email, lockout after five failures for fifteen minutes and a twelve-character mixed password policy.
- TOTP MFA with protected secrets, accepted-time-step replay prevention and ten one-time recovery codes stored only as HMAC digests.
- Random server-tracked sessions with digest-only identifiers, security-stamp binding, idle and absolute expiry, revocation and sign-out-all support.
- `__Host-` Secure/HttpOnly/SameSite=Strict cookies, strict antiforgery checks on unsafe controller actions and IP-partitioned authentication throttling.
- Tenant route authorization and platform-administrator MFA policies.
- Password reset responses that do not disclose account existence; reset tokens are placed only inside a purpose-isolated Data Protection payload in an insert-only queue.

## Executed evidence

The `AuthenticationFlowTests.PasswordMfaRbacInvitationAndSignOutFlowUsesRealPostgreSql18` scenario starts the exact PostgreSQL 18.4 image, migrates it as owner, provisions a restricted runtime login, boots the real HTTP application and proves:

1. a wrong password receives the uniform unauthorized response;
2. the correct password enters MFA enrollment rather than a fully privileged session;
3. tenant-administrator work is denied before MFA;
4. a generated TOTP completes enrollment and returns ten distinct recovery codes once;
5. the full session carries MFA and the expected tenant role;
6. a same-tenant invitation succeeds while another tenant route is forbidden; and
7. sign-out revokes the server-side session.

The complete local test run passes 48 .NET tests and 4 React tests. Notification delivery, browser E2E and remote CI remain open and are not claimed.
