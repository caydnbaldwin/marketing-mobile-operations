#!/usr/bin/env bash
# Returns 0 if the palera1n app is present on the connected iOS device, 1 otherwise.
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
# Meant to be sourced. Do not execute directly.

verify_palera1n_installed() {
    if ideviceinstaller list --all 2>/dev/null | grep -qi "palera1n"; then
        echo_mmo SUCCESS "palera1n successfully installed on device."
        return 0
    else
        echo_mmo FAILURE "palera1n not found on device." >&2
        return 1
    fi
}
