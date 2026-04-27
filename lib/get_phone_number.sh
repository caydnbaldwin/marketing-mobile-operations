#!/usr/bin/env bash
# Queries the phone's MSISDN via lockdownd. Phone must be plugged in over USB;
# `pymobiledevice3 lockdown get` talks to lockdownd via usbmux. The `PhoneNumber`
# key is populated once the SIM is inserted and registered with the carrier —
# returns 1 (with no stdout) if it isn't there yet, so callers can render a
# fallback rather than abort.
#
# Output is the raw value pymobiledevice3 prints (Python-repr style with quotes
# on strings); we strip surrounding quotes/whitespace before printing.
#
# Args: none
# On success: prints the number to stdout, returns 0.
# On failure: silent, returns 1.
#
# No echo_mmo dependency — this is a probe, not a workflow step.
# Meant to be sourced. Do not execute directly.

get_phone_number() {
    local raw
    raw=$(pymobiledevice3 lockdown get --key PhoneNumber 2>/dev/null) || return 1
    raw=$(printf '%s' "$raw" | tr -d "\"'" | tr -d '[:space:]')
    if [ -z "$raw" ] || [ "$raw" = "None" ] || [ "$raw" = "null" ]; then
        return 1
    fi
    printf '%s\n' "$raw"
}
