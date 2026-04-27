#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/wait_for_lockdownd.sh"
source "$ROOT_DIR/lib/verify_device_language.sh"
source "$ROOT_DIR/lib/verify_palera1n_installed.sh"
source "$ROOT_DIR/lib/wait_for_palera1n_installed.sh"

echo_mmo HEADER "Stage 1 verification"

wait_for_lockdownd
verify_device_language en en_US
wait_for_palera1n_installed
