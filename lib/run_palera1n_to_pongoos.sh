#!/usr/bin/env bash
# Runs palera1n with the given args, polls USB for PongoOS to appear,
# then terminates palera1n. palera1n v2.2.1 on macOS / iPhone 6s hangs
# after booting PongoOS instead of exiting — the prior manual workflow
# was Ctrl+C; this function automates it so a second palera1n call can
# pick up from the PongoOS state on the device.
#
# Unlike an output-capture approach, palera1n's stdout/stderr go directly
# to the caller's terminal so its interactive DFU countdown keeps working
# (palera1n disables the countdown if it detects no TTY). We detect
# PongoOS by polling ioreg for the PongoOS USB device (product name
# "Pongo" or product ID 0x4141 = 16705).
#
# Usage: run_palera1n_to_pongoos <palera1n flags>
#        e.g. run_palera1n_to_pongoos -f -c
#
# Returns 0 if PongoOS was detected and palera1n was terminated.
# Returns 1 if palera1n exited before PongoOS appeared, or detection
# timed out (15 minutes — bumped from 11 because slow phones on the
# FakeFS-creation call were still tripping the shorter budget; tighter
# timeouts force the operator into a full rerun).
#
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
# Meant to be sourced. Do not execute directly.

run_palera1n_to_pongoos() {
    palera1n "$@" &
    local pal_pid=$!

    local timeout=900
    local start=$SECONDS
    local last_heartbeat=0
    local elapsed

    while kill -0 "$pal_pid" 2>/dev/null; do
        if ioreg -p IOUSB -l 2>/dev/null | grep -qiE 'pongo|idProduct.*= 16705'; then
            # Let PongoOS finish initializing on the device before we pull the plug on the host.
            sleep 3
            echo ""
            echo_mmo INFO "(PongoOS detected on USB — terminating palera1n so the next call can continue)"
            kill -INT "$pal_pid" 2>/dev/null || true
            sleep 2
            kill -KILL "$pal_pid" 2>/dev/null || true
            pkill -KILL -P "$pal_pid" 2>/dev/null || true
            wait "$pal_pid" 2>/dev/null || true
            return 0
        fi

        elapsed=$((SECONDS - start))

        if (( elapsed >= timeout )); then
            echo "" >&2
            echo_mmo FAILURE "Timed out waiting for PongoOS on USB after ${timeout}s" >&2
            kill -KILL "$pal_pid" 2>/dev/null || true
            pkill -KILL -P "$pal_pid" 2>/dev/null || true
            wait "$pal_pid" 2>/dev/null || true
            return 1
        fi

        # Heartbeat every 60s while we wait. palera1n's own output runs
        # interleaved here, so the [MMO] prefix is what makes our progress
        # line stand out.
        if (( elapsed >= last_heartbeat + 60 && elapsed > 0 )); then
            last_heartbeat=$elapsed
            echo_mmo WARNING "Still waiting for PongoOS on USB (${elapsed}s elapsed of ${timeout}s)..."
        fi

        sleep 1
    done

    wait "$pal_pid" 2>/dev/null || true
    echo_mmo FAILURE "palera1n exited before PongoOS appeared on USB" >&2
    return 1
}
