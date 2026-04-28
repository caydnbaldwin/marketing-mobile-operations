#!/usr/bin/env bash
# Looks up the palera1n loader app's bundle ID via `pymobiledevice3 apps list`.
# Different palera1n builds have used different IDs — current ones use
# `in.palera.loader`, older builds were `com.cydia.PalEra1n`, etc. — querying
# at runtime is more durable than hardcoding.
#
# Strategy: scan all installed bundle IDs (system + user) for one whose
# identifier contains "palera" (case-insensitive). We match on "palera", NOT
# "palera1n", because the canonical bundle ID `in.palera.loader` doesn't
# contain the digit "1n" — only the project name does. Returns the first match.
# Phone must be plugged in over USB; pymobiledevice3 talks to lockdownd via
# usbmux, no jailbreak-side dependency.
#
# Args: none
# On success: prints the bundle ID to stdout, returns 0.
# On failure: silent, returns 1.
#
# Requires `jq` in PATH.
# No echo_mmo dependency — this is a probe, not a workflow step.
# Meant to be sourced. Do not execute directly.

get_palera1n_bundle_id() {
    local bundle_id
    bundle_id=$(pymobiledevice3 apps list 2>/dev/null \
        | jq -r 'keys[] | select(ascii_downcase | contains("palera"))' \
        | head -n 1)
    if [ -z "$bundle_id" ]; then
        return 1
    fi
    printf '%s\n' "$bundle_id"
}
