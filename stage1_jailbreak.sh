#!/usr/bin/env bash
set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

info()    { echo "[INFO]  $*"; }
prompt()  { echo; echo "[ACTION] $*"; read -rp "         Press Enter when ready..."; echo; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

command -v palera1n >/dev/null 2>&1 || die "palera1n not found in PATH"
command -v irecovery >/dev/null 2>&1 || die "irecovery not found in PATH (needed for device state detection)"

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

palera1n -f -c

# palera1n puts device into recovery; script pauses for DFU button combo
prompt "When palera1n says it's ready: hold Power + Home on the iPhone to enter DFU/pongoOS, then press Enter."

# ── step 2 ───────────────────────────────────────────────────────────────────
info "Step 2/5 — Second palera1n run (jailbreak)"
wait_for_device "recovery" > /dev/null

palera1n -f -c

info "Jailbreak payload sent. Waiting for iPhone to reboot..."

# wait for device to disappear then reappear in any state
sleep 5
state=$(wait_for_device "any")

# ── step 3 ───────────────────────────────────────────────────────────────────
info "Step 3/5 — Post-reboot state: $state"

if [ "$state" = "normal" ]; then
    info "Device booted normally. Sending back to recovery..."
    palera1n -f
elif [ "$state" = "recovery" ]; then
    info "Device landed in recovery mode. Running palera1n -f..."
    palera1n -f
fi

# ── step 4 ───────────────────────────────────────────────────────────────────
prompt "When palera1n says it's ready: hold Power + Home on the iPhone to enter pongoOS, then press Enter."

# ── step 5 ───────────────────────────────────────────────────────────────────
info "Step 4/5 — Final palera1n run (boot jailbroken)"
wait_for_device "recovery" > /dev/null

palera1n -f

info "Step 5/5 — Waiting for iPhone to boot jailbroken..."
wait_for_device "normal" > /dev/null

echo
echo "============================================"
echo "  Stage 1 complete — iPhone is jailbroken!"
echo "============================================"
