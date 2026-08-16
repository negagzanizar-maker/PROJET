# Provisioning Raspberry Pi

## Supported baseline

The release target is Raspberry Pi OS 64-bit on Raspberry Pi 4 or 5. The device needs outbound HTTPS/DNS/NTP, Chromium, `curl`, `systemd`, and the native libraries required by the self-contained .NET arm64 publication. No inbound customer-router rule is needed: the backend connection is initiated by the agent and the player listens only on `127.0.0.1:8787`.

The kiosk launcher detects an available Wayland socket and otherwise uses X11. The installer can bind it to an existing graphical user with `--kiosk-user`; this is the reliable field-test profile for current Raspberry Pi OS desktop images. The separate non-login kiosk identity remains the hardened baseline for an image whose graphical seat permissions are provisioned explicitly.

## Release artifact

For a laptop-and-Pi test on the same Wi-Fi, use the complete [quick field-test runbook](FIELD_TEST_TOMORROW.md). It builds the archive automatically and provisions private-LAN HTTPS trust.

Build the player first so it is embedded into the agent publication, then create an immutable archive:

```bash
npm --prefix apps/player-web ci
npm --prefix apps/player-web run build
dotnet publish src/DisplayControl.DeviceAgent/DisplayControl.DeviceAgent.csproj \
  --configuration Release --runtime linux-arm64 --self-contained true \
  --output artifacts/pi/linux-arm64
tar -C artifacts/pi/linux-arm64 -czf artifacts/display-control-pi-linux-arm64.tar.gz .
sha256sum artifacts/display-control-pi-linux-arm64.tar.gz
```

The SHA-256 must be transported through an independently trusted release channel. This installer verifies a supplied digest; a production release still needs the separately signed update-metadata workflow recorded in the security requirements.

## First enrollment

1. Create an enrollment code for the expected serial in the tenant dashboard.
2. Place only that code in a root-readable temporary file on the Pi.
3. Copy `deploy/pi` and the verified release archive to the Pi.
4. Run:

```bash
sudo deploy/pi/install.sh \
  --artifact ./display-control-pi-linux-arm64.tar.gz \
  --sha256 '<trusted 64-character digest>' \
  --version '1.0.0' \
  --server 'https://control.example.com' \
  --enrollment-code-file './enrollment-code.txt'
```

For a Raspberry Pi OS desktop field test, add `--kiosk-user "$(whoami)"`. For a private LAN server signed by the generated field-test CA, also add `--server-ca ./field-test-server-ca.crt`. Production uses a publicly trusted server certificate and does not install this local CA.

The installer always creates a non-login `display-control-agent` account and, unless a graphical user is supplied, a separate `display-control-kiosk` account. It creates owner-only state directories, immutable root-owned releases, hardened service units, and an atomic `current` symlink. The agent reads the copied one-time enrollment file and deletes it only after the certificate and pinned licence-verification key have been validated and persisted.

## Validation

```bash
systemctl status display-control-agent display-control-kiosk
curl --fail http://127.0.0.1:8787/player/v1/health
journalctl -u display-control-agent -u display-control-kiosk --since today
test ! -e /var/lib/display-control/enrollment-code
ss -lntp | grep 8787
```

The port check must show loopback only. Chromium must run without `--no-sandbox` and without a remote-debugging port. Reboot, network loss/recovery, licence expiry, corrupt-cache, browser restart, Pi 4, and Pi 5 evidence remain physical acceptance gates and cannot be claimed from a workstation test.

## Remote-access baseline

Disable VNC and unused remote services. If SSH is operationally required, use key-only authentication, an allowlisted management path/firewall, a separate named administrator account, and retained authentication logs. Application users and device certificates must never be reused as operating-system credentials.
