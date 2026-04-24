#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/verify_palera1n_installed.sh"

palera1n -f -c
palera1n -f -c
palera1n -f
palera1n -f

sleep 3

verify_palera1n_installed
