#!/usr/bin/env bash
# Polls `pymobiledevice3 lockdown info` until it responds or ~120s elapses.
# Use at the top of stage 1 verification: palera1n's last call returns the
# moment the kernel starts booting, not when iOS is up. lockdownd doesn't come
# back online until ~30-60s later, so any instant lockdownd query that runs
# right after stage 1 (e.g. `verify_device_language`) hard-fails for no reason
# other than timing. This wait absorbs the post-boot gap.
#
# 120s budget covers the slow-boot case with margin; on a fully-booted phone
# the first poll succeeds in <1s so there's no real cost when invoked
# standalone (e.g. `mmo -s1v` on a long-running phone).
# Emits a WARNING heartbeat every 30s so the operator knows it's still polling.
#
# Returns 0 on success, 1 on timeout.
# Requires echo_mmo to already be sourced by the caller.
# Meant to be sourced. Do not execute directly.

wait_for_lockdownd() {
    echo_mmo INFO "Waiting for lockdownd to come back after reboot (up to 120s)..."
    local i seconds
    for i in $(seq 1 40); do
        if pymobiledevice3 lockdown info >/dev/null 2>&1; then
            return 0
        fi
        # Heartbeat at 30s, 60s, 90s — but not at 120s
        # (the FAILURE message below covers that case).
        if (( i % 10 == 0 && i < 40 )); then
            seconds=$((i * 3))
            echo_mmo WARNING "Still waiting for lockdownd (${seconds}s elapsed of 120s)..."
        fi
        sleep 3
    done
    echo_mmo FAILURE "lockdownd did not respond within 120s." >&2
    return 1
}
