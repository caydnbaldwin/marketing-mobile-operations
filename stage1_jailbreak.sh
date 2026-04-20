#!/usr/bin/env bash
set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

info()   { echo "[INFO]  $*"; }
prompt() { echo; echo "[ACTION] $*"; read -rp "         Press Enter when ready..."; echo; }
die()    { echo "[ERROR] $*" >&2; exit 1; }

command -v palera1n >/dev/null 2>&1 || die "palera1n not found in PATH"
command -v irecovery >/dev/null 2>&1 || die "irecovery not found in PATH"

PALERA1N_PID=""

# Start palera1n in the background (non-blocking). Call stop_palera1n when done.
start_palera1n() {
    setsid palera1n "$@" &
    PALERA1N_PID=$!
    trap "kill $PALERA1N_PID 2>/dev/null; true" INT EXIT
}

# Wait 10 seconds then kill the running palera1n process.
stop_palera1n() {
    info "pongoOS booting — stopping palera1n in 10 seconds..."
    sleep 10
    kill "$PALERA1N_PID" 2>/dev/null || true
    wait "$PALERA1N_PID" 2>/dev/null || true
    PALERA1N_PID=""
    trap - INT EXIT
    info "palera1n stopped — continuing..."
}

# Run palera1n and wait for it to exit naturally (no auto-kill).
run_palera1n() {
    setsid palera1n "$@" &
    local pid=$!
    trap "kill $pid 2>/dev/null; true" INT EXIT
    wait $pid || true
    trap - INT EXIT
    info "palera1n exited — continuing..."
}

# ── device state detection ───────────────────────────────────────────────────

detect_device() {
    if irecovery -q 2>/dev/null | grep -q "CPID"; then
        echo "recovery"
    elif lsusb 2>/dev/null | grep -qi "apple"; then
        echo "normal"
    else
        echo "none"
    fi
}

wait_for_device() {
    local target="$1"
    local timeout=120
    local elapsed=0
    info "Waiting for device (target: $target)..."
    while [ $elapsed -lt $timeout ]; do
        local state
        state=$(detect_device)
        if [ "$target" = "any" ] && [ "$state" != "none" ]; then
            info "Device detected in state: $state"
            echo "$state"
            return 0
        elif [ "$state" = "$target" ]; then
            info "Device in $target mode."
            echo "$state"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    die "Timed out waiting for device in state: $target"
}

# ── stage 1 ──────────────────────────────────────────────────────────────────

echo "============================================"
echo "  Stage 1 — iPhone Jailbreak via palera1n"
echo "============================================"
echo

# ── step 1 ───────────────────────────────────────────────────────────────────
info "Step 1/5 — First palera1n run (create fs)"
prompt "Ensure the iPhone is plugged in, then press Enter to begin."

start_palera1n -f -c
prompt "Hold Power + Home on the iPhone when palera1n prompts for DFU. Press Enter once pongoOS is booting."
stop_palera1n

# ── step 2 ───────────────────────────────────────────────────────────────────
info "Step 2/5 — Second palera1n run (jailbreak)"
wait_for_device "recovery" > /dev/null

run_palera1n -f -c

info "Jailbreak payload sent. Waiting for iPhone to reboot..."
sleep 5
state=$(wait_for_device "any")

# ── step 3 ───────────────────────────────────────────────────────────────────
info "Step 3/5 — Post-reboot state: $state — sending to recovery..."
start_palera1n -f
prompt "Hold Power + Home on the iPhone when palera1n prompts for DFU. Press Enter once pongoOS is booting."
stop_palera1n

# ── step 4 ───────────────────────────────────────────────────────────────────
info "Step 4/5 — Final palera1n run (boot jailbroken)"
wait_for_device "recovery" > /dev/null

run_palera1n -f

# ── step 5 ───────────────────────────────────────────────────────────────────
info "Step 5/5 — Waiting for iPhone to boot jailbroken..."
wait_for_device "normal" > /dev/null

echo
echo "============================================"
echo "  Stage 1 complete — iPhone is jailbroken!"
echo "============================================"
