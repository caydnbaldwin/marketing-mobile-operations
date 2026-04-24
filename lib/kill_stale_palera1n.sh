#!/usr/bin/env bash
# Kills any running `palera1n` (or its child `checkra1n` helper) processes
# on the host. palera1n runs as root and, when left alive after an aborted
# jailbreak (Ctrl+C, closed terminal), silently grabs the next USB device
# it sees and forces it into DFU/recovery. Its child `checkra1n` (extracted
# at runtime to /var/folders/.../T//checkra1n.XXXXXX) can outlive the
# parent as an orphan and hold exclusive USB access, which causes the next
# palera1n invocation to fail with `kIOReturnExclusiveAccess` (0xe00002c5).
#
# Needs root to kill root-owned processes; calls `sudo` internally so it
# works both from an already-elevated caller (stage 1) and from an
# unprivileged run.sh invocation.
#
# Returns 0 whether or not any processes were killed.
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
# Meant to be sourced. Do not execute directly.

kill_stale_palera1n() {
    # Anchored `^palera1n` matches the parent process by command name.
    # `/checkra1n\.` matches the temp-extracted child, whose full argv
    # always contains the literal path fragment `/T//checkra1n.<random>`.
    local pattern='(^palera1n|/checkra1n\.)'
    local pids
    pids=$(pgrep -f "$pattern" 2>/dev/null || true)
    if [ -z "$pids" ]; then
        echo_mmo "No stale palera1n processes found."
        return 0
    fi
    echo_mmo "Killing stale palera1n processes: $(echo "$pids" | tr '\n' ' ')"
    sudo pkill -9 -f "$pattern" 2>/dev/null || true
    return 0
}
