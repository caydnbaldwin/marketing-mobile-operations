#!/usr/bin/env bash
# Extracts the phone's WiFi IPv4 via a brief USB SSH tunnel. Starts iproxy
# on $USB_SSH_PORT, SSHes as mobile@localhost, runs `ipconfig getifaddr en0`
# (with an ifconfig fallback), and tears down the tunnel. lockdownd /
# pymobiledevice3 expose only MAC addresses, not the DHCP-assigned IP, so
# SSH is the only deterministic path.
#
# Requires env vars: SSH_PASS, USB_SSH_PORT (usually from .env).
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
#
# On success: prints ONLY the IP to stdout, returns 0.
# On failure: prints error via echo_mmo >&2, returns 1.
#
# Meant to be sourced. Do not execute directly.

get_wifi_ip() {
    local iproxy_pid wifi_ip i
    local ssh_opts=(
        -p "$USB_SSH_PORT"
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
        -o ConnectTimeout=10
        -o PubkeyAuthentication=no
        -o PreferredAuthentications=keyboard-interactive,password
        -o NumberOfPasswordPrompts=1
    )

    pkill -f "iproxy $USB_SSH_PORT" 2>/dev/null && sleep 1 || true

    iproxy "$USB_SSH_PORT" 22 >/dev/null 2>&1 &
    iproxy_pid=$!
    sleep 2

    if ! kill -0 "$iproxy_pid" 2>/dev/null; then
        echo_mmo FAILURE "iproxy failed to start on port $USB_SSH_PORT" >&2
        return 1
    fi

    for i in $(seq 1 30); do
        if sshpass -p "$SSH_PASS" ssh "${ssh_opts[@]}" mobile@localhost true 2>/dev/null; then
            break
        fi
        sleep 2
    done

    wifi_ip=$(sshpass -p "$SSH_PASS" ssh "${ssh_opts[@]}" mobile@localhost \
        "ipconfig getifaddr en0 2>/dev/null || ifconfig en0 2>/dev/null | awk '/inet /{print \$2; exit}'" \
        2>/dev/null | tr -d '[:space:]')

    kill "$iproxy_pid" 2>/dev/null || true

    if [ -z "$wifi_ip" ]; then
        echo_mmo FAILURE "Phone reports no IPv4 address on en0" >&2
        return 1
    fi

    printf '%s\n' "$wifi_ip"
    return 0
}
