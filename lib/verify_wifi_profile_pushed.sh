#!/usr/bin/env bash
# Returns 0 if the Stage2 WiFi configuration profile (PayloadIdentifier
# `com.stage2.wifi`, the value push_wifi_profile writes) is already
# installed on the connected device, 1 otherwise.
#
# Probes via `pymobiledevice3 profile list` over USB/lockdownd. Same
# channel verify_sileo_installed and verify_device_reachable use, so no
# new tool dependency.
#
# Silent — callers print SKIP/INFO if appropriate.
# Meant to be sourced. Do not execute directly.

verify_wifi_profile_pushed() {
    pymobiledevice3 profile list 2>/dev/null | grep -q "com.stage2.wifi"
}
