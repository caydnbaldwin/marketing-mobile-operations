#!/usr/bin/env bash
# Runs a command on the phone over palera1n's bundled dropbear SSH (USB
# tunnel via iproxy on port 44). Connects as the `mobile` user with
# $SSH_PASS — that account's password is set during the "Install Sileo"
# step in the palera1n app, so this function only works AFTER that step.
# Before Install Sileo, dropbear is listening but no account on the phone
# has a usable password (`/etc/master.passwd` has root as `!` and mobile
# as `*`), and the SSH attempt will fail with "Permission denied".
#
# Why dropbear specifically: stage 2 uses this to bootstrap OpenSSH onto
# the phone, so the device-side OpenSSH on port 22 isn't installed yet.
# Dropbear is bundled in palera1n's binpack at /cores/binpack/Library/
# LaunchDaemons/dropbear-*.plist and runs from boot.
#
# Why mobile@ and not root@: this palera1n build's /etc/master.passwd has
# root locked out (`root:!:...`). Dropbear authenticates against
# master.passwd, so root login is impossible regardless of password.
# Use mobile + sudo for elevated commands.
#
# Requires env vars: SSH_PASS (from .env).
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
# Requires sshpass and iproxy on the host (Homebrew).
#
# Usage:
#   run_via_dropbear "uname -a"
#   run_via_dropbear "echo '$SSH_PASS' | sudo -S -k apt-get install -y openssh"
#
# On success: forwards stdout/stderr of the remote command unprefixed
# (matches the project's convention for third-party tool output), returns
# the remote command's exit code.
# On iproxy / auth failure: prints diagnostic via echo_mmo >&2, returns 1.
#
# Meant to be sourced. Do not execute directly.

run_via_dropbear() {
    local remote_cmd="$1"
    local local_port=2244
    local iproxy_pid rc i
    local ssh_opts=(
        -p "$local_port"
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
        -o ConnectTimeout=10
        -o PubkeyAuthentication=no
        -o PreferredAuthentications=keyboard-interactive,password
        -o NumberOfPasswordPrompts=1
    )

    pkill -f "iproxy $local_port" 2>/dev/null && sleep 1 || true

    iproxy "$local_port" 44 >/dev/null 2>&1 &
    iproxy_pid=$!
    sleep 2

    if ! kill -0 "$iproxy_pid" 2>/dev/null; then
        echo_mmo FAILURE "iproxy failed to start (port $local_port -> phone:44)" >&2
        return 1
    fi

    # Wait for dropbear to accept. Post-Install-Sileo this should auth on
    # the first try, but a sluggish bootstrap finalisation can briefly
    # leave master.passwd in flux — the loop tolerates that.
    for i in $(seq 1 15); do
        if sshpass -p "$SSH_PASS" ssh "${ssh_opts[@]}" mobile@localhost true 2>/dev/null; then
            break
        fi
        sleep 1
    done

    sshpass -p "$SSH_PASS" ssh "${ssh_opts[@]}" mobile@localhost "$remote_cmd"
    rc=$?

    kill "$iproxy_pid" 2>/dev/null || true

    return $rc
}
