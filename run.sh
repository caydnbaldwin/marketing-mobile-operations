#!/usr/bin/env bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
[ -L "$SOURCE" ] && SOURCE="$(readlink -f "$SOURCE")"
ROOT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

source "$ROOT_DIR/lib/print_help.sh"

case "${1:-}" in
    "")
        "$ROOT_DIR/stages/stage1_jailbreak.sh"
        "$ROOT_DIR/stages/stage2_sileo_openssh.sh"
        ;;
    --stage1)
        "$ROOT_DIR/stages/stage1_jailbreak.sh"
        ;;
    --stage2)
        "$ROOT_DIR/stages/stage2_sileo_openssh.sh"
        ;;
    --verify-palera1n-installed)
        source "$ROOT_DIR/lib/verify_palera1n_installed.sh"
        verify_palera1n_installed
        ;;
    -h|--help)
        print_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        print_help >&2
        exit 1
        ;;
esac
