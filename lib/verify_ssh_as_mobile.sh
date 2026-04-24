#!/usr/bin/env bash
# Verifies that we can SSH into the phone over WiFi as the `mobile` user
# with $SSH_PASS. A successful connection proves three things at once:
# sshd is running (OpenSSH installed), the password matches what the
# operator entered during Sileo install, and the WiFi path is usable from
# the Mac (same thing the /setup-new-phone skill does as its first SSH).
#
# Requires env var: SSH_PASS (usually from .env).
#
# Usage: verify_ssh_as_mobile <ip>
# Returns 0 on successful auth + command execution, 1 otherwise.
# Meant to be sourced. Do not execute directly.

verify_ssh_as_mobile() {
    local ip="$1"
    sshpass -p "$SSH_PASS" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ConnectTimeout=10 \
        -o PubkeyAuthentication=no \
        -o PreferredAuthentications=keyboard-interactive,password \
        -o NumberOfPasswordPrompts=1 \
        "mobile@$ip" true 2>/dev/null
}
