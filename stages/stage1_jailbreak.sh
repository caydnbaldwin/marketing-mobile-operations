#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/verify_palera1n_installed.sh"
source "$ROOT_DIR/lib/wait_for_palera1n_installed.sh"

echo "Stage 1 will call palera1n 4 times."
echo "You will be asked to hold Power + Home for DFU mode TWICE (calls 1 and 3)."
echo "Calls 2 and 4 continue from PongoOS over USB and do not need DFU."
echo ""

echo "[1/4] Entering DFU -> checkm8 -> PongoOS (hold Power + Home when prompted)..."
palera1n -f -c
sleep 2

echo "[2/4] Uploading FakeFS-creation payload via PongoOS (no DFU needed)..."
palera1n -f -c

echo "[3/4] Re-entering DFU for jailbreak boot (hold Power + Home when prompted)..."
palera1n -f
sleep 2

echo "[4/4] Booting jailbroken chain via PongoOS (no DFU needed)..."
palera1n -f

wait_for_palera1n_installed
