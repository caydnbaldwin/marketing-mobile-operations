#!/usr/bin/env bash
# Launches the Messages app on the phone via `uiopen sms://` over dropbear.
# Once Messages comes to the foreground, iOS surfaces the Local Network
# permission prompt for `com.apple.MobileSMS` if it hasn't been granted
# yet. The operator still has to tap Allow on the prompt — the grant
# itself lives in /private/var/preferences/com.apple.networkextension.plist
# as a complex NSKeyedArchiver-serialized blob (NOT in TCC.db on iOS 15),
# and writing it from a shell risks corrupting Local Network state for
# every app on the device. So this is "open Messages for the operator"
# automation, not an unattended grant.
#
# Idempotent: if Local Network permission was already granted, no prompt
# appears. Messages just opens.
#
# Requires uikittools on the phone (provides /usr/bin/uiopen — included
# in palera1n's Procursus bootstrap by default).
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
# Requires echo_mmo to be in scope.
#
# Returns 0 on success, non-zero on SSH failure.
#
# Meant to be sourced. Do not execute directly.

trigger_local_network_prompt() {
    if run_via_dropbear "uiopen 'sms://'"; then
        echo_mmo SUCCESS "Messages launched on the phone."
        return 0
    fi
    echo_mmo FAILURE "Failed to launch Messages over dropbear." >&2
    return 1
}
