#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/verify_device_reachable.sh"
source "$ROOT_DIR/lib/run_via_dropbear.sh"
source "$ROOT_DIR/lib/install_openssh_via_dropbear.sh"
source "$ROOT_DIR/lib/trigger_local_network_prompt.sh"
source "$ROOT_DIR/lib/get_palera1n_bundle_id.sh"
source "$ROOT_DIR/lib/launch_app_via_ddi.sh"
source "$ROOT_DIR/lib/launch_sileo_app.sh"

push_wifi_profile() {
    local tmpdir tmp out rc=0
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
    # pymobiledevice3 logs "ERROR Device is not connected" but exits 0, so we
    # capture stderr and inspect it ourselves. Treat any ERROR line as failure.
    out=$(pymobiledevice3 profile install "$tmp" 2>&1) || rc=$?
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -q "ERROR"; then
        echo_mmo FAILURE "WiFi profile install failed: ${out:-no output}" >&2
        return 1
    fi
    return 0
}

echo_mmo HEADER "Stage 2: WiFi, Sileo, OpenSSH, Local Network"

verify_device_reachable

sleep 2

# --- Manual bridge 1: WiFi profile install -----------------------------------
echo_mmo INFO "Pushing WiFi configuration profile to device..."
push_wifi_profile

cat <<EOF | echo_mmo INFO

============================================
  On the iPhone:
  Settings > General > VPN & Device Management
  Tap 'Stage2 WiFi' > Install
  The device will auto-join: ${WIFI_SSID}
============================================
EOF
read -rp "[MMO] Press Enter once the device is on WiFi... "

# --- Manual bridge 2: Install Sileo (this sets mobile's password) ------------
echo_mmo INFO "Opening palera1n loader app on the phone..."
PALERA1N_BUNDLE_ID=$(get_palera1n_bundle_id || true)
if [ -n "$PALERA1N_BUNDLE_ID" ]; then
    launch_app_via_ddi "$PALERA1N_BUNDLE_ID" || true
else
    echo_mmo WARNING "Could not auto-detect palera1n loader bundle ID — open the app manually."
fi

cat <<EOF | echo_mmo INFO

============================================
  On the iPhone (palera1n app should now be
  open; if not, open it from the Home screen):
  1. Tap 'Install Sileo'
  2. Set password:     ${SSH_PASS}
  3. Confirm password: ${SSH_PASS}
  Wait for Sileo to finish installing.
  (Sets the password on the 'mobile' user;
   the next two steps SSH in as that user
   over dropbear/USB to finish setup.)
============================================
EOF
read -rp "[MMO] Press Enter when Sileo is installed and password is set... "

echo_mmo INFO "Opening Sileo on the phone..."
launch_sileo_app || true

# --- Automated bridge 3: install OpenSSH via dropbear over USB ---------------
echo_mmo INFO "Installing OpenSSH via Procursus apt over dropbear (USB)..."
install_openssh_via_dropbear

# --- Semi-automated bridge 4: launch Messages so iOS surfaces the prompt -----
echo_mmo INFO "Launching Messages on the phone over dropbear..."
trigger_local_network_prompt

cat <<EOF | echo_mmo INFO

============================================
  On the iPhone:
  Approve the 'Local Network' permission
  prompt for Messages (if shown).
  (Without it the iMessageGateway tweak
   later fails with EHOSTUNREACH. If the
   prompt doesn't appear, permission was
   already granted — just press Enter.)
============================================
EOF
read -rp "[MMO] Press Enter once the Local Network prompt is approved (or absent)... "
