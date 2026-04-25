#!/usr/bin/env bash
# Verifies the device's UI language + regional locale match the expected
# values (default en / en_US). Reads via lockdownd, same channel
# set_device_language writes through. Exists so stage 1 verification can
# confirm set_device_language stuck through the jailbreak reboots and the
# operator never lands on a Chinese-localized Settings menu in stage 2.
#
# Usage:
#   verify_device_language                # checks for en / en_US
#   verify_device_language en en_US
#   verify_device_language es es_ES
#
# Returns 0 if both language and locale match the expected values,
# 1 if either doesn't match or lockdownd is unreachable.
#
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
# Requires pymobiledevice3 on the host.
# Meant to be sourced. Do not execute directly.

verify_device_language() {
    local expected_lang="${1:-en}"
    local expected_locale="${2:-en_US}"
    local current_lang current_locale

    current_lang=$(pymobiledevice3 lockdown language 2>/dev/null) || current_lang=""
    current_locale=$(pymobiledevice3 lockdown locale 2>/dev/null) || current_locale=""
    current_lang=${current_lang//\"/}
    current_locale=${current_locale//\"/}

    if [ -z "$current_lang" ] || [ -z "$current_locale" ]; then
        echo_mmo FAILURE "Could not query device language (is the phone plugged in and paired?)" >&2
        return 1
    fi

    if [ "$current_lang" = "$expected_lang" ] && [ "$current_locale" = "$expected_locale" ]; then
        echo_mmo SUCCESS "Device language is ${expected_lang} (${expected_locale})."
        return 0
    fi

    echo_mmo FAILURE "Device language mismatch: got ${current_lang}/${current_locale}, expected ${expected_lang}/${expected_locale}." >&2
    return 1
}
