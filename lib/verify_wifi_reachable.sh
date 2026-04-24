#!/usr/bin/env bash
# Pings the phone from the Mac over WiFi. This is the exact reachability
# check the /setup-new-phone skill does first (`ping -c 2 -W 2000 $IP`).
# Phone-side `ping` isn't installed on palera1n by default, so we probe
# from the Mac.
#
# Usage: verify_wifi_reachable <ip>
# Returns 0 if the phone replies to at least one ICMP echo, 1 otherwise.
# Meant to be sourced. Do not execute directly.

verify_wifi_reachable() {
    local ip="$1"
    ping -c 1 -W 1000 "$ip" >/dev/null 2>&1
}
