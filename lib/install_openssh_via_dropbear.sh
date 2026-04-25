#!/usr/bin/env bash
# Installs the openssh package on the phone via Procursus apt, run over
# dropbear SSH (USB). Idempotent — `apt-get install -y openssh` is a no-op
# when openssh is already installed.
#
# Replaces the manual "Open Sileo, search 'openssh by Nick Chan', install
# the 4-package bundle" bridge from earlier stage 2 versions. Same end
# state — sshd on port 22, mobile auth via $SSH_PASS — just no taps.
#
# Requires env vars: SSH_PASS.
# Depends on lib/run_via_dropbear.sh (caller must source it first).
# Requires echo_mmo to be in scope.
#
# Returns 0 on success, non-zero on apt or SSH failure.
#
# Meant to be sourced. Do not execute directly.

install_openssh_via_dropbear() {
    local apt_cmd="echo '$SSH_PASS' | sudo -S -k sh -c 'apt-get update -qq && apt-get install -y openssh'"
    if run_via_dropbear "$apt_cmd"; then
        echo_mmo SUCCESS "OpenSSH installed via Procursus apt."
        return 0
    fi
    echo_mmo FAILURE "OpenSSH install failed over dropbear." >&2
    return 1
}
