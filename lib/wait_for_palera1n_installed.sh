#!/usr/bin/env bash
# Polls verify_palera1n_installed until it returns 0 or ~180s elapses.
# Use after stage 1 finishes, to absorb the device's post-jailbreak boot.
# 180s (was 60s) covers the slow-boot case we've seen where the phone
# takes 2+ minutes to repopulate the home screen after the chain-boot.
# Emits a WARNING heartbeat every 30s so the operator knows the script
# is still polling and not hung.
# Returns 0 on success, 1 on timeout.
# Requires verify_palera1n_installed and echo_mmo to already be sourced by the caller.
# Meant to be sourced. Do not execute directly.

wait_for_palera1n_installed() {
    echo_mmo INFO "Waiting for palera1n to appear on device (up to 180s)..."
    local i seconds
    for i in $(seq 1 60); do
        if verify_palera1n_installed 2>/dev/null; then
            return 0
        fi
        # Heartbeat at 30s, 60s, 90s, 120s, 150s — but not at 180s
        # (the FAILURE message below covers that case).
        if (( i % 10 == 0 && i < 60 )); then
            seconds=$((i * 3))
            echo_mmo WARNING "Still waiting for palera1n (${seconds}s elapsed of 180s)..."
        fi
        sleep 3
    done
    echo_mmo FAILURE "palera1n not found on device after 180s." >&2
    return 1
}
