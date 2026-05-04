#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/kill_stale_palera1n.sh"
source "$ROOT_DIR/lib/run_palera1n_to_pongoos.sh"
source "$ROOT_DIR/lib/set_device_language.sh"
source "$ROOT_DIR/lib/verify_palera1n_installed.sh"

CURRENT_STEP="initializing"
trap 'echo_mmo FAILURE "Stage 1 aborted at step: $CURRENT_STEP" >&2' ERR

echo_mmo HEADER "Stage 1: Jailbreak (palera1n)"

# Top-level guard: jailbreak is atomic (DFU/PongoOS state is transient and
# not a meaningful skip boundary), so a single probe at the top elides the
# whole stage on a re-run against an already-jailbroken phone.
CURRENT_STEP="palera1n-installed pre-check"
if verify_palera1n_installed 2>/dev/null; then
    echo_mmo SKIP "Phone already jailbroken — skipping stage 1"
    exit 0
fi

# Force the device into English BEFORE we jailbreak: phones that come from
# sourcing in zh-Hans-CN would otherwise leave stage 2's "Settings > VPN &
# Device Management" tap in Chinese. Idempotent — no-op if already en/en_US.
# Non-fatal: on a first-time connection the phone may not have accepted the
# Trust pairing prompt yet, so lockdownd refuses the language query. Continue
# anyway; the operator can re-run `mmo -sdl` once lockdownd is reachable.
CURRENT_STEP="device language preflight"
set_device_language en en_US || echo_mmo WARNING "Language preflight failed — continuing. Re-run \`mmo -sdl\` later if Settings menus aren't in English."

CURRENT_STEP="kill stale palera1n/checkra1n"
kill_stale_palera1n

CURRENT_STEP="[1/4] DFU -> checkm8 -> PongoOS"
echo_mmo INFO "[1/4] Entering DFU -> checkm8 -> PongoOS (hold Power + Home when prompted)..."
run_palera1n_to_pongoos -f -c
sleep 2

CURRENT_STEP="[2/4] FakeFS payload upload via PongoOS"
echo_mmo INFO "[2/4] Uploading FakeFS-creation payload via PongoOS (no DFU needed)..."
palera1n -f -c

CURRENT_STEP="[3/4] re-DFU -> checkm8 -> PongoOS"
echo_mmo INFO "[3/4] Re-entering DFU for jailbreak boot (hold Power + Home when prompted)..."
run_palera1n_to_pongoos -f
sleep 2

CURRENT_STEP="[4/4] booting jailbroken chain via PongoOS"
echo_mmo INFO "[4/4] Booting jailbroken chain via PongoOS (no DFU needed)..."
palera1n -f
