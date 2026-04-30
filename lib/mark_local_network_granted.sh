#!/usr/bin/env bash
# Drops the .mmo_local_network_granted marker file in
# /var/mobile/Library/Preferences/ via dropbear, signaling "the operator
# has confirmed the iOS Local Network grant for Messages." Stage 2 calls
# this immediately after the operator presses Enter past the Local Network
# prompt; verify_local_network_granted reads it on subsequent runs to
# skip step 5 entirely.
#
# Path choice: /var/mobile/Library/Preferences/ is mobile-owned (so no
# sudo needed) and stable across reboots. /tmp would be wiped, /var/run
# is volatile, and sticking it under root-owned paths would force sudo.
#
# Why a separate writer lib (rather than a touch tacked onto the end of
# trigger_local_network_prompt): trigger_local_network_prompt is "open
# Messages" — it's also reused as a generic foreground-Messages helper.
# The marker write is a distinct semantic step ("operator confirmed the
# grant"), so it lives in its own lib.
#
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
# Requires echo_mmo to be in scope.
#
# Returns 0 on success, non-zero on SSH failure. Failure here is not
# fatal — it just means the next run will re-prompt the operator — so
# callers can `|| true` it if they want to be lenient.
#
# Meant to be sourced. Do not execute directly.

mark_local_network_granted() {
    if run_via_dropbear "touch /var/mobile/Library/Preferences/.mmo_local_network_granted"; then
        return 0
    fi
    echo_mmo WARNING "Failed to write Local Network grant marker — next run will re-prompt." >&2
    return 1
}
