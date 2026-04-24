#!/usr/bin/env bash
# Polls verify_palera1n_installed until it returns 0 or ~60s elapses.
# Use after stage 1 finishes, to absorb the device's post-jailbreak boot.
# Returns 0 on success, 1 on timeout.
# Requires verify_palera1n_installed and echo_mmo to already be sourced by the caller.
# Meant to be sourced. Do not execute directly.

wait_for_palera1n_installed() {
    echo_mmo "Waiting for palera1n to appear on device (up to 60s)..."
    for _ in $(seq 1 20); do
        if verify_palera1n_installed 2>/dev/null; then
            return 0
        fi
        sleep 3
    done
    echo_mmo "palera1n not found on device after 60s." >&2
    return 1
}
