#!/usr/bin/env bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
[ -L "$SOURCE" ] && SOURCE="$(readlink -f "$SOURCE")"
ROOT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

source "$ROOT_DIR/lib/print_help.sh"

case "${1:-}" in
    "")
        "$ROOT_DIR/stages/stage1_jailbreak.sh"
        "$ROOT_DIR/stages/stage1_verification.sh"
        "$ROOT_DIR/stages/stage2_sileo_openssh.sh"
        "$ROOT_DIR/stages/stage2_verification.sh"
        "$ROOT_DIR/stages/stage3_imessagegateway.sh"
        "$ROOT_DIR/stages/stage3_verification.sh"
        ;;
    --stage1|-s1)
        "$ROOT_DIR/stages/stage1_jailbreak.sh"
        ;;
    --stage1-verification|-s1v)
        "$ROOT_DIR/stages/stage1_verification.sh"
        ;;
    --stage2|-s2)
        "$ROOT_DIR/stages/stage2_sileo_openssh.sh"
        ;;
    --stage2-verification|-s2v)
        "$ROOT_DIR/stages/stage2_verification.sh"
        ;;
    --stage3|-s3)
        "$ROOT_DIR/stages/stage3_imessagegateway.sh"
        ;;
    --stage3-verification|-s3v)
        "$ROOT_DIR/stages/stage3_verification.sh"
        ;;
    --verify-palera1n-installed|-vpi)
        source "$ROOT_DIR/lib/echo_mmo.sh"
        source "$ROOT_DIR/lib/verify_palera1n_installed.sh"
        verify_palera1n_installed
        ;;
    --kill-stale-palera1n|-ksp)
        source "$ROOT_DIR/lib/echo_mmo.sh"
        source "$ROOT_DIR/lib/kill_stale_palera1n.sh"
        kill_stale_palera1n
        ;;
    --set-device-language|-sdl)
        source "$ROOT_DIR/lib/echo_mmo.sh"
        source "$ROOT_DIR/lib/set_device_language.sh"
        set_device_language "${2:-en}" "${3:-en_US}"
        ;;
    --run-setup-new-phone-skill|-rsnps)
        source "$ROOT_DIR/lib/echo_mmo.sh"
        source "$ROOT_DIR/lib/run_setup_new_phone_skill.sh"
        if [ -n "${2:-}" ]; then
            IP="$2"
            PASS="${3:-alpine1}"
        else
            # shellcheck source=.env
            source "$ROOT_DIR/.env"
            source "$ROOT_DIR/lib/get_wifi_ip.sh"
            echo_mmo INFO "Discovering phone WiFi IP..."
            IP=$(get_wifi_ip)
            PASS="$SSH_PASS"
        fi
        run_setup_new_phone_skill "$IP" "$PASS"
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
