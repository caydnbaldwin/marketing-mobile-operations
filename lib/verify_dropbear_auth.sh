#!/usr/bin/env bash
# Returns 0 if dropbear accepts mobile@phone with the current $SSH_PASS,
# 1 otherwise. Used as the second half of the Sileo-step dual-probe:
# verify_sileo_installed proves Sileo is on disk, verify_dropbear_auth
# proves the password set during Sileo install matches what's in .env.
#
# Without this dual-probe, a Sileo-installed phone with a stale/different
# password silently passes the skip check and downstream OpenSSH install
# fails with an opaque dropbear auth error.
#
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
#
# Silent — callers print SKIP/INFO if appropriate. run_via_dropbear's own
# diagnostic prints are suppressed via stderr redirect.
# Meant to be sourced. Do not execute directly.

verify_dropbear_auth() {
    run_via_dropbear "true" >/dev/null 2>&1
}
