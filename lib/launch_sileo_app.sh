#!/usr/bin/env bash
# Launches the Sileo app on the phone via `uiopen sileo://` over dropbear.
# Mirrors trigger_local_network_prompt's pattern (which does the same thing
# for Messages with sms://). Called in stage 2 after the operator confirms
# the manual Sileo install — by then mobile has a hash in /etc/master.passwd
# so dropbear authenticates, and Sileo's URL scheme is registered. The
# point is UX: bring Sileo to the foreground so the operator can see it
# (and let it warm its source indexes) without an extra Home-screen tap,
# while OpenSSH installs in the background over the same dropbear tunnel.
#
# Idempotent. Best-effort: returns 1 if dropbear/uiopen failed but the
# stage shouldn't abort — opening Sileo is a UX nicety, not a precondition
# for the OpenSSH install that follows.
#
# Requires uikittools on the phone (provides /usr/bin/uiopen — included
# in palera1n's Procursus bootstrap by default, present once Sileo is in).
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
# Requires echo_mmo to be in scope.
#
# Returns 0 on success, 1 on SSH/uiopen failure.
#
# Meant to be sourced. Do not execute directly.

launch_sileo_app() {
    if run_via_dropbear "uiopen 'sileo://'"; then
        echo_mmo SUCCESS "Sileo launched on the phone."
        return 0
    fi
    echo_mmo WARNING "Failed to launch Sileo over dropbear — open it manually if you need it."
    return 1
}
