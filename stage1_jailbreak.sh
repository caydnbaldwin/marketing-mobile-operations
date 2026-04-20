#!/usr/bin/env bash
set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

info()    { echo "[INFO]  $*"; }
prompt()  { echo; echo "[ACTION] $*"; read -rp "         Press Enter when ready..."; echo; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

command -v palera1n >/dev/null 2>&1 || die "palera1n not found in PATH"
command -v irecovery >/dev/null 2>&1 || die "irecovery not found in PATH (needed for device state detection)"

# Runs palera1n in its own session so Ctrl+C kills only palera1n, not this script.
# After pongoOS boots, press Ctrl+C — the script will catch it and continue.
run_palera1n() {
    setsid palera1n "$@" &
    local pid=$!
    trap "kill $pid 2>/dev/null; true" INT
    wait $pid || true
    trap - INT
    echo
    info "palera1n exited — continuing..."
}

# ── device state detection ───────────────────────────────────────────────────

# Returns "recovery" if device is in recovery/DFU mode, "normal" if connected normally, "none" if not found
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
    local target="$1"   # "recovery" or "normal" or "any"
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
prompt "Ensure the iPhone is plugged in and unlocked, then press Enter to begin."

run_run_palera1n -f -c

# palera1n puts device into recovery; user presses buttons then Ctrl+C to kill palera1n once pongoOS boots
prompt "Hold Power + Home on the iPhone when prompted by palera1n to enter DFU. Once pongoOS boots, press Ctrl+C to exit palera1n, then press Enter here."

# ── step 2 ───────────────────────────────────────────────────────────────────
info "Step 2/5 — Second palera1n run (jailbreak)"
wait_for_device "recovery" > /dev/null

run_run_palera1n -f -c

info "Jailbreak payload sent. Waiting for iPhone to reboot..."

# wait for device to disappear then reappear in any state
sleep 5
state=$(wait_for_device "any")

# ── step 3 ───────────────────────────────────────────────────────────────────
info "Step 3/5 — Post-reboot state: $state"

if [ "$state" = "normal" ]; then
    info "Device booted normally. Sending back to recovery..."
    run_palera1n -f
elif [ "$state" = "recovery" ]; then
    info "Device landed in recovery mode. Running run_palera1n -f..."
    run_palera1n -f
fi

# ── step 4 ───────────────────────────────────────────────────────────────────
prompt "Hold Power + Home on the iPhone when prompted by palera1n to enter pongoOS. Once pongoOS boots, press Ctrl+C to exit palera1n, then press Enter here."

# ── step 5 ───────────────────────────────────────────────────────────────────
info "Step 4/5 — Final palera1n run (boot jailbroken)"
wait_for_device "recovery" > /dev/null

run_palera1n -f

info "Step 5/5 — Waiting for iPhone to boot jailbroken..."
wait_for_device "normal" > /dev/null

echo
echo "============================================"
echo "  Stage 1 complete — iPhone is jailbroken!"
echo "============================================"
