#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

_ssh() {
    sshpass -p "$SSH_PASS" ssh \
        -p "$USB_SSH_PORT" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        root@localhost "$@"
}

wait_for_ssh() {
    echo "Waiting for SSH..."
    for _ in $(seq 1 30); do
        if _ssh true 2>/dev/null; then
            echo "SSH ready."
            return 0
        fi
        sleep 2
    done
    echo "SSH not available after 60s." >&2
    exit 1
}

push_wifi_profile() {
    local tmp
    tmp=$(mktemp /tmp/wifi_XXXXXX.mobileconfig)
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
    python3 -m pymobiledevice3 profile install "$tmp"
    rm -f "$tmp"
}

# ── main ──────────────────────────────────────────────────────────────────

sleep 2

echo "Pushing WiFi configuration profile to device..."
push_wifi_profile

echo ""
echo "============================================"
echo "  On the iPhone:"
echo "  Settings > General > VPN & Device Management"
echo "  Tap 'Stage2 WiFi' > Install"
echo "  The device will auto-join: ${WIFI_SSID}"
echo "============================================"
read -rp "Press Enter once the device is on WiFi... "

echo ""
echo "============================================"
echo "  On the iPhone:"
echo "  1. Open the palera1n app"
echo "  2. Tap 'Install Sileo'"
echo "  3. Set password:     alpine1"
echo "  4. Confirm password: alpine1"
echo "  Wait for Sileo to finish installing."
echo "============================================"
read -rp "Press Enter when Sileo is installed and password is set... "

iproxy "$USB_SSH_PORT" 22 &
IPROXY_PID=$!
trap 'kill "$IPROXY_PID" 2>/dev/null || true' EXIT
sleep 2

wait_for_ssh

echo "Accepting Sileo analytics..."
_ssh "defaults write xyz.willy.Sileo sendAnalytics -bool YES 2>/dev/null || true"

echo "Refreshing package sources..."
_ssh "apt-get update -y 2>&1"

echo "Installing OpenSSH by Nick Chan..."
_ssh "apt-get install -y openssh 2>&1"

verify() {
    local wifi_ok=false sileo_ok=false openssh_count=0 all_ok=true

    if _ssh "ping -c 1 -W 3 8.8.8.8" >/dev/null 2>&1; then
        wifi_ok=true
    fi

    if _ssh "dpkg-query -W -f='\${Status}' sileo 2>/dev/null" | grep -q "install ok installed"; then
        sileo_ok=true
    fi

    openssh_count=$(_ssh "dpkg -l 2>/dev/null | awk '/^ii.*openssh/{c++} END{print c+0}'" 2>/dev/null || echo 0)

    local wifi_status sileo_status openssh_status
    if $wifi_ok;   then wifi_status="OK";    else wifi_status="FAIL";                     all_ok=false; fi
    if $sileo_ok;  then sileo_status="OK";   else sileo_status="FAIL";                    all_ok=false; fi
    if [ "$openssh_count" -ge 4 ]; then
        openssh_status="OK ($openssh_count packages)"
    else
        openssh_status="FAIL ($openssh_count packages)"
        all_ok=false
    fi

    echo ""
    echo "============================================"
    echo "  Stage 2 Verification"
    echo "============================================"
    printf "  %-26s %s\n" "WiFi (${WIFI_SSID}):" "$wifi_status"
    printf "  %-26s %s\n" "Sileo:"               "$sileo_status"
    printf "  %-26s %s\n" "OpenSSH:"              "$openssh_status"
    echo "============================================"

    if $all_ok; then
        echo "  All checks passed."
    else
        echo "  One or more checks failed." >&2
        exit 1
    fi
}

verify
