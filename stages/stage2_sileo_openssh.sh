#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"

push_wifi_profile() {
    local tmpdir tmp
    tmpdir=$(mktemp -d)
    tmp="$tmpdir/wifi.mobileconfig"
    cat > "$tmp" <<PROFILE
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>AutoJoin</key><true/>
            <key>EncryptionType</key><string>WPA2</string>
            <key>Password</key><string>${WIFI_PASS}</string>
            <key>PayloadDisplayName</key><string>Wi-Fi</string>
            <key>PayloadIdentifier</key><string>com.apple.wifi.managed.stage2</string>
            <key>PayloadType</key><string>com.apple.wifi.managed</string>
            <key>PayloadUUID</key><string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>
            <key>PayloadVersion</key><integer>1</integer>
            <key>SSID_STR</key><string>${WIFI_SSID}</string>
        </dict>
    </array>
    <key>PayloadDisplayName</key><string>Stage2 WiFi</string>
    <key>PayloadIdentifier</key><string>com.stage2.wifi</string>
    <key>PayloadRemovalDisallowed</key><false/>
    <key>PayloadType</key><string>Configuration</string>
    <key>PayloadUUID</key><string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>
    <key>PayloadVersion</key><integer>1</integer>
</dict>
</plist>
PROFILE
    pymobiledevice3 profile install "$tmp"
    rm -rf "$tmpdir"
}

echo_mmo "Stage 2: WiFi, Sileo, OpenSSH"

sleep 2

echo_mmo "Pushing WiFi configuration profile to device..."
push_wifi_profile

cat <<EOF | echo_mmo

============================================
  On the iPhone:
  Settings > General > VPN & Device Management
  Tap 'Stage2 WiFi' > Install
  The device will auto-join: ${WIFI_SSID}
============================================
EOF
read -rp "[MMO] Press Enter once the device is on WiFi... "

cat <<EOF | echo_mmo

============================================
  On the iPhone:
  1. Open the palera1n app
  2. Tap 'Install Sileo'
  3. Set password:     ${SSH_PASS}
  4. Confirm password: ${SSH_PASS}
  Wait for Sileo to finish installing.
  (This sets the password on the 'mobile' user,
   which is who we SSH in as.)
============================================
EOF
read -rp "[MMO] Press Enter when Sileo is installed and password is set... "

cat <<EOF | echo_mmo

============================================
  On the iPhone, install OpenSSH via Sileo:
  1. Open Sileo
  2. Allow notifications, accept analytics
  3. Search for: openssh by Nick Chan
  4. Tap Get, then Queue (auto-selects 4 packages)
  5. Confirm installation
  6. Tap Done when install finishes
  (OpenSSH must be installed here — palera1n does not ship
   an SSH daemon by default.)
============================================
EOF
read -rp "[MMO] Press Enter when OpenSSH is installed... "

cat <<EOF | echo_mmo

============================================
  On the iPhone:
  Tap Messages on the home screen and wait
  for it to finish loading. If prompted,
  approve Local Network access.
  (This grants the permission the
   iMessageGateway tweak needs — without it,
   setup-new-phone fails with EHOSTUNREACH.)
============================================
EOF
read -rp "[MMO] Press Enter once Messages has finished loading... "
