#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

# ── helpers ───────────────────────────────────────────────────────────────────

info()   { echo "[INFO]  $*"; }
prompt() { echo; echo "[ACTION] $*"; read -rp "         Press Enter when ready..."; echo; }
die()    { echo "[ERROR] $*" >&2; exit 1; }

command -v palera1n >/dev/null 2>&1         || die "palera1n not found in PATH"
command -v irecovery >/dev/null 2>&1        || die "irecovery not found in PATH"
command -v ideviceinstaller >/dev/null 2>&1 || die "ideviceinstaller not found in PATH"

info "Stopping usbmuxd..."
systemctl stop usbmuxd 2>/dev/null || true

# ── process management ────────────────────────────────────────────────────────

PALERA1N_PID=""
PALERA1N_FIFO=""

# Kill everything that could be holding a libusb handle on the device.
cleanup_palera1n() {
    if [ -n "$PALERA1N_PID" ]; then
        kill -9 -- -"$PALERA1N_PID" 2>/dev/null || true
        wait "$PALERA1N_PID" 2>/dev/null || true
        PALERA1N_PID=""
    fi
    exec 9>&- 2>/dev/null || true
    [ -n "$PALERA1N_FIFO" ] && rm -f "$PALERA1N_FIFO" && PALERA1N_FIFO=""
    pkill -9 -x palera1n  2>/dev/null || true
    pkill -9 -x checkra1n 2>/dev/null || true
    pkill -9 -x irecovery  2>/dev/null || true
    sleep 1
}

# Run palera1n with a FIFO as stdin.
# This prevents the background process from getting an immediate EOF (which
# would cause palera1n to skip its own "Press Enter" prompt and start the DFU
# countdown before the user is ready).
start_palera1n() {
    cleanup_palera1n
    PALERA1N_FIFO=$(mktemp -u /tmp/palera1n_fifo_XXXX)
    mkfifo "$PALERA1N_FIFO"
    exec 9<>"$PALERA1N_FIFO"         # O_RDWR open never blocks; keeps pipe alive so palera1n never gets EOF
    setsid palera1n "$@" < "$PALERA1N_FIFO" &
    PALERA1N_PID=$!
    trap "cleanup_palera1n" INT EXIT
}

# Relay an Enter keystroke to palera1n's stdin via the FIFO.
# palera1n blocks on "Press Enter when ready for DFU mode" until this is called.
palera1n_enter() {
    echo >&9
}

# Wait for pongoOS to boot (it presents a USB CDC-ACM serial device on /dev/ttyACM*).
# Kill palera1n once detected — it hangs after pongoOS boots anyway.
wait_for_pongoos_and_stop() {
    local timeout=120
    local elapsed=0
    info "Waiting for pongoOS to boot (watching /dev/ttyACM*)..."
    while [ $elapsed -lt $timeout ]; do
        if ls /dev/ttyACM* 2>/dev/null | grep -q .; then
            info "pongoOS detected — stopping palera1n in 5 seconds..."
            sleep 5
            cleanup_palera1n
            info "palera1n stopped — continuing..."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    # Fallback: ttyACM never appeared (permissions issue, module not loaded, etc.)
    # Let the user confirm manually.
    info "Auto-detection timed out."
    prompt "If pongoOS has booted on the iPhone, press Enter to continue."
    cleanup_palera1n
    info "palera1n stopped — continuing..."
}

# Run palera1n and wait for it to exit naturally (used for the final boot step).
run_palera1n() {
    cleanup_palera1n
    setsid palera1n "$@" &
    local pid=$!
    trap "kill -9 -- -$pid 2>/dev/null; true" INT EXIT
    wait $pid || true
    trap - INT EXIT
    info "palera1n exited — continuing..."
}

# ── device detection ──────────────────────────────────────────────────────────

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

# ── stage 1 ───────────────────────────────────────────────────────────────────

echo "============================================"
echo "  Stage 1 — iPhone Jailbreak via palera1n"
echo "============================================"
echo

# ── step 1: create FakeFS ────────────────────────────────────────────────────
info "Step 1/4 — palera1n -f -c (create FakeFS)"
start_palera1n -f -c
prompt "Wait for palera1n to say 'Press Enter when ready for DFU mode'. Before pressing Enter here: place your thumb on Home and a finger on Power so your hands are already on the phone. Then press Enter — the countdown starts immediately. When the line changes from 'Hold home + power button' to 'Hold home button', release Power INSTANTLY and keep holding Home until DFU is confirmed."
palera1n_enter
wait_for_pongoos_and_stop

# ── step 2: jailbreak ────────────────────────────────────────────────────────
info "Step 2/4 — palera1n -f (jailbreak)"
wait_for_device "any" > /dev/null

start_palera1n -f
prompt "Wait for palera1n to say 'Press Enter when ready for DFU mode'. Before pressing Enter here: place your thumb on Home and a finger on Power so your hands are already on the phone. Then press Enter — the countdown starts immediately. When the line changes from 'Hold home + power button' to 'Hold home button', release Power INSTANTLY and keep holding Home until DFU is confirmed."
palera1n_enter
wait_for_pongoos_and_stop

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

info "Restarting usbmuxd for verification..."
systemctl start usbmuxd 2>/dev/null || true
sleep 3

info "Verifying palera1n app is installed..."
if ideviceinstaller -l 2>/dev/null | grep -qi "palera1n"; then
    echo
    echo "============================================"
    echo "  Stage 1 complete — iPhone is jailbroken!"
    echo "============================================"
else
    die "palera1n app not found — jailbreak may not have completed successfully."
fi
