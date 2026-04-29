#!/usr/bin/env bash
# Returns 0 if the OpenSSH server binary is present and executable on the
# phone, 1 otherwise. Probes via dropbear/USB so it works pre-WiFi and
# before phone-side OpenSSH is up on port 22.
#
# Why /usr/sbin/sshd: that's the path Procursus's openssh package installs
# to. If the package is missing, the file is missing.
#
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
# Note: dropbear auth itself depends on Sileo install having set mobile's
# password — if dropbear can't auth, this probe returns 1 regardless of
# whether sshd is on disk. That's the right behavior; we can't know the
# state of the phone if we can't talk to it.
#
# Silent — callers print SKIP/INFO if appropriate. run_via_dropbear's own
# diagnostic prints are suppressed via stderr redirect.
# Meant to be sourced. Do not execute directly.

verify_openssh_installed() {
    run_via_dropbear "test -x /usr/sbin/sshd" >/dev/null 2>&1
}
