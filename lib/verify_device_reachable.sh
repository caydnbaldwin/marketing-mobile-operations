#!/usr/bin/env bash
# Verifies the iPhone is reachable over USB by querying lockdownd. Used as a
# precheck at the top of stages that talk to the device, because pymobiledevice3
# has a misbehavior where it logs "ERROR Device is not connected" to stderr
# but exits 0 — `set -e` doesn't trip, and stages silently proceed past failed
# device operations (e.g. printing "now tap Install on the WiFi profile" when
# the profile was never actually pushed).
#
# We treat any ERROR pattern in stdout+stderr OR empty output as failure;
# a connected device produces a multi-line key/value dump.
#
# Args: none
# Returns: 0 if device is reachable via lockdownd, 1 otherwise.
# Requires echo_mmo to be in scope.
# Meant to be sourced. Do not execute directly.

verify_device_reachable() {
    local out
    out=$(pymobiledevice3 lockdown info 2>&1) || true
    if [ -z "$out" ] || printf '%s' "$out" | grep -q "ERROR"; then
        echo_mmo FAILURE "Device not reachable over USB." >&2
        echo_mmo FAILURE "  Check: Lightning cable (try another), USB port (direct on Mac, not a hub)," >&2
        echo_mmo FAILURE "         phone awake + unlocked, 'Trust This Computer' accepted." >&2
        echo_mmo FAILURE "         If the phone is wedged, hold Power + Home ~10s to force-restart." >&2
        return 1
    fi
    return 0
}
