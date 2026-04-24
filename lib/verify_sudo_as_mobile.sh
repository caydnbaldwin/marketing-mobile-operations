#!/usr/bin/env bash
# Verifies that the `mobile` user can `sudo` to root using $SSH_PASS. The
# /setup-new-phone skill's root-password bootstrap step (step 2) runs
# `sudo -S passwd root` as mobile, so this check proves that path will
# succeed before stage 3 hands off.
#
# Requires env var: SSH_PASS (usually from .env).
#
# Usage: verify_sudo_as_mobile <ip>
# Returns 0 if `sudo -S -k whoami` prints `root`, 1 otherwise.
# Meant to be sourced. Do not execute directly.

verify_sudo_as_mobile() {
    local ip="$1" out
    out=$(sshpass -p "$SSH_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ConnectTimeout=10 \
        -o PubkeyAuthentication=no \
        -o PreferredAuthentications=keyboard-interactive,password \
        -o NumberOfPasswordPrompts=1 \
        "mobile@$ip" \
        "echo '$SSH_PASS' | sudo -S -k whoami 2>/dev/null")
    [ "$out" = "root" ]
}
