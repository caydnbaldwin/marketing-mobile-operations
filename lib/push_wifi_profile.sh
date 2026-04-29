#!/usr/bin/env bash
# Generates a WiFi .mobileconfig from $WIFI_SSID/$WIFI_PASS and pushes it to
# the connected iPhone via `pymobiledevice3 profile install` over USB.
# The operator still has to tap Install in Settings > VPN & Device Management
# (Apple gates silent profile install behind device supervision, which would
# require wiping the phone — out of scope), but this function gets the
# profile onto the device so the prompt appears.
#
# The PayloadIdentifier is hardcoded to `com.stage2.wifi`; that's the value
# verify_wifi_profile_pushed greps for, so don't change it without updating
# the probe in lockstep.
#
# pymobiledevice3 has a quirk where it logs "ERROR Device is not connected"
# to stderr but exits 0 — we capture stderr and grep for ERROR ourselves so
# silent failures don't leak past `set -e`. The stage-level
# verify_device_reachable precheck should catch a fully-disconnected device,
# but transient/partial failures can still surface here.
#
# Requires env vars: WIFI_SSID, WIFI_PASS (from .env).
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
#
# Returns 0 on success, 1 on failure.
# Meant to be sourced. Do not execute directly.

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
    out=$(pymobiledevice3 profile install "$tmp" 2>&1) || rc=$?
    rm -rf "$tmpdir"
    if [ "$rc" -ne 0 ] || printf '%s' "$out" | grep -q "ERROR"; then
        echo_mmo FAILURE "WiFi profile install failed: ${out:-no output}" >&2
        echo_mmo FAILURE "  Check: phone awake + unlocked, no profile-install dialog already" >&2
        echo_mmo FAILURE "         open in Settings (close it and rerun), USB cable seated." >&2
        return 1
    fi
    return 0
}
