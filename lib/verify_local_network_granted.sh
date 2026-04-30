#!/usr/bin/env bash
# Returns 0 if the .mmo_local_network_granted marker file exists in
# /var/mobile/Library/Preferences/, 1 otherwise. Probes via dropbear/USB
# (does not depend on phone-side OpenSSH or WiFi).
#
# The marker is our proxy for "the operator already granted iOS Local
# Network for Messages" — the actual grant lives in
# /private/var/preferences/com.apple.networkextension.plist as an
# NSKeyedArchiver-serialized blob, which isn't safely shell-readable. So
# instead we drop a sentinel file (via mark_local_network_granted) the
# first time the operator confirms the prompt; subsequent stage 2 runs
# read the marker and skip step 5.
#
# Caveat: the marker only proves "we did this once" — if the operator
# later revokes the grant in Settings, the marker stays and stage 3 will
# fail with EHOSTUNREACH. Recovery is to delete the marker and re-run
# stage 2.
#
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
# Note: dropbear auth itself depends on Sileo install having set mobile's
# password — if dropbear can't auth, this probe returns 1 regardless of
# whether the marker is on disk. That's the right behavior; we can't know
# the state of the phone if we can't talk to it.
#
# Silent — callers print SKIP/INFO if appropriate. run_via_dropbear's own
# diagnostic prints are suppressed via stderr redirect.
# Meant to be sourced. Do not execute directly.

verify_local_network_granted() {
    run_via_dropbear "test -f /var/mobile/Library/Preferences/.mmo_local_network_granted" >/dev/null 2>&1
}
