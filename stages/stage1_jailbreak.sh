#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/kill_stale_palera1n.sh"
source "$ROOT_DIR/lib/run_palera1n_to_pongoos.sh"
source "$ROOT_DIR/lib/set_device_language.sh"

echo_mmo HEADER "Stage 1: Jailbreak (palera1n)"

# Force the device into English BEFORE we jailbreak: phones that come from
# sourcing in zh-Hans-CN would otherwise leave stage 2's "Settings > VPN &
# Device Management" tap in Chinese. Idempotent — no-op if already en/en_US.
set_device_language en en_US

kill_stale_palera1n

echo_mmo INFO "[1/4] Entering DFU -> checkm8 -> PongoOS (hold Power + Home when prompted)..."
run_palera1n_to_pongoos -f -c
sleep 2

echo_mmo INFO "[2/4] Uploading FakeFS-creation payload via PongoOS (no DFU needed)..."
palera1n -f -c

echo_mmo INFO "[3/4] Re-entering DFU for jailbreak boot (hold Power + Home when prompted)..."
run_palera1n_to_pongoos -f
sleep 2

echo_mmo INFO "[4/4] Booting jailbroken chain via PongoOS (no DFU needed)..."
palera1n -f
