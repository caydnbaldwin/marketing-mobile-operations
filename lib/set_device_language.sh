#!/usr/bin/env bash
# Sets the device's UI language and regional locale via lockdownd, so phones
# that arrive from sourcing in zh-Hans-CN / zh_CN don't make the operator
# navigate Chinese menus during stage 2's "Settings > VPN & Device Management"
# tap. Works pre-jailbreak (lockdownd is available on stock iOS) and does
# NOT require supervision — Apple gates a lot of MDM-ish settings behind
# the supervised-device flag, but the AppleLanguages / AppleLocale keys
# happen to be writable from any paired host.
#
# The change persists across reboots (writes to the device's user defaults)
# and is picked up by SpringBoard on next launch — stage 1's jailbreak reboots
# flush it for free, so we don't need to trigger a respring ourselves.
#
# Idempotent: queries current language/locale first; if it already matches
# the target, just logs and returns without re-writing.
#
# Usage:
#   set_device_language                 # defaults: en, en_US
#   set_device_language en en_US
#   set_device_language es es_ES        # if ever needed
#
# Returns 0 on success or no-op (already correct).
# Returns 1 if lockdownd is unreachable (phone unplugged / not paired) or
# if either set call fails.
#
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
# Requires pymobiledevice3 on the host.
# Meant to be sourced. Do not execute directly.

set_device_language() {
    local target_lang="${1:-en}"
    local target_locale="${2:-en_US}"
    local current_lang current_locale

    current_lang=$(pymobiledevice3 lockdown language 2>/dev/null) || current_lang=""
    current_locale=$(pymobiledevice3 lockdown locale 2>/dev/null) || current_locale=""
    current_lang=${current_lang//\"/}
    current_locale=${current_locale//\"/}

    if [ -z "$current_lang" ] || [ -z "$current_locale" ]; then
        echo_mmo FAILURE "Could not query device language (is the phone plugged in and paired?)" >&2
        return 1
    fi

    if [ "$current_lang" = "$target_lang" ] && [ "$current_locale" = "$target_locale" ]; then
        echo_mmo INFO "Device language already $target_lang ($target_locale) — no change."
        return 0
    fi

    echo_mmo INFO "Setting device language: ${current_lang} -> ${target_lang}, ${current_locale} -> ${target_locale}"
    if ! pymobiledevice3 lockdown language "$target_lang" >/dev/null 2>&1; then
        echo_mmo FAILURE "lockdownd refused language=$target_lang" >&2
        return 1
    fi
    if ! pymobiledevice3 lockdown locale "$target_locale" >/dev/null 2>&1; then
        echo_mmo FAILURE "lockdownd refused locale=$target_locale" >&2
        return 1
    fi
    echo_mmo SUCCESS "Device language set to ${target_lang} (${target_locale})."
    return 0
}
