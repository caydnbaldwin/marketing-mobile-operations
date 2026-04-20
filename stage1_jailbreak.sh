#!/usr/bin/env bash
set -euo pipefail

# palera1n requires root to open the USB device node without a race condition
# against udev setting permissions — re-exec with sudo if not already root.
[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

# ── helpers ──────────────────────────────────────────────────────────────────

info()   { echo "[INFO]  $*"; }
prompt() { echo; echo "[ACTION] $*"; read -rp "         Press Enter when ready..."; echo; }
die()    { echo "[ERROR] $*" >&2; exit 1; }

command -v palera1n >/dev/null 2>&1        || die "palera1n not found in PATH"
command -v irecovery >/dev/null 2>&1       || die "irecovery not found in PATH"
command -v ideviceinstaller >/dev/null 2>&1 || die "ideviceinstaller not found in PATH"

# usbmuxd holds the USB interface open and causes palera1n to fail with
# "Resource busy". Stop it before any palera1n runs; restore it before
# ideviceinstaller needs it at the end.
info "Stopping usbmuxd to free USB interface for palera1n..."
systemctl stop usbmuxd 2>/dev/null || true

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

# ── step 1: create FakeFS ────────────────────────────────────────────────────
info "Step 1/4 — palera1n -f -c (create FakeFS)"
prompt "Ensure the iPhone is plugged in, then press Enter to begin."

start_palera1n -f -c
prompt "Hold Power + Home when palera1n prompts for DFU. Press Enter once pongoOS is booting."
stop_palera1n

# ── step 2: jailbreak ────────────────────────────────────────────────────────
info "Step 2/4 — palera1n -f (jailbreak)"
wait_for_device "any" > /dev/null

start_palera1n -f
prompt "Hold Power + Home when palera1n prompts for DFU. Press Enter once pongoOS is booting."
stop_palera1n

# ── step 3: boot jailbroken ──────────────────────────────────────────────────
info "Step 3/4 — palera1n -f (boot jailbroken)"
wait_for_device "any" > /dev/null

run_palera1n -f

# ── step 4: verify ───────────────────────────────────────────────────────────
info "Step 4/4 — Waiting for iPhone to boot..."
wait_for_device "normal" > /dev/null

prompt "Press the Home button on the iPhone to reach the home screen, then press Enter."

info "Waiting 10 seconds for device to settle..."
sleep 10

info "Restarting usbmuxd for app verification..."
systemctl start usbmuxd 2>/dev/null || true
sleep 3

info "Verifying palera1n app is installed..."
if ideviceinstaller -l 2>/dev/null | grep -qi "palera1n"; then
    echo
    echo "============================================"
    echo "  Stage 1 complete — iPhone is jailbroken!"
    echo "============================================"
else
    die "palera1n app not found on device — jailbreak may not have completed successfully."
fi
