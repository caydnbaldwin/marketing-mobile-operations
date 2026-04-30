#!/usr/bin/env bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
[ -L "$SOURCE" ] && SOURCE="$(readlink -f "$SOURCE")"
ROOT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

source "$ROOT_DIR/lib/print_help.sh"

# No args: full pipeline.
if [ $# -eq 0 ]; then
    "$ROOT_DIR/stages/stage1_jailbreak.sh"
    "$ROOT_DIR/stages/stage1_verification.sh"
    "$ROOT_DIR/stages/stage2_sileo_openssh.sh"
    "$ROOT_DIR/stages/stage2_verification.sh"
    "$ROOT_DIR/stages/stage3_imessagegateway.sh"
    "$ROOT_DIR/stages/stage3_verification.sh"
    exit 0
fi

# Atomic ops with positional args are single-call: anything after the flag
# belongs to the op (e.g. `-sdl es es_ES`, `-rsnps 10.x.x.x alpine1`), not
# subsequent flags. Branch out of multi-flag dispatch entirely for these.
case "${1:-}" in
    --set-device-language|-sdl)
        source "$ROOT_DIR/lib/echo_mmo.sh"
        source "$ROOT_DIR/lib/set_device_language.sh"
        set_device_language "${2:-en}" "${3:-en_US}"
        exit 0
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
        exit 0
        ;;
esac

# Multi-flag dispatch. Two passes:
#   1. Expand `-sN/v` shorthand into `-sN -sNv` so the dispatch loop only
#      handles canonical flags.
#   2. Walk the expanded list and dispatch each in order. `set -e` aborts on
#      the first failure, matching the historical && chain semantics.
expanded=()
for arg in "$@"; do
    case "$arg" in
        -s1/v|--stage1/v) expanded+=(-s1 -s1v) ;;
        -s2/v|--stage2/v) expanded+=(-s2 -s2v) ;;
        -s3/v|--stage3/v) expanded+=(-s3 -s3v) ;;
        *)                expanded+=("$arg") ;;
    esac
done

for flag in "${expanded[@]}"; do
    case "$flag" in
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
            if verify_palera1n_installed; then
                echo_mmo SUCCESS "palera1n successfully installed on device."
            else
                echo_mmo FAILURE "palera1n not found on device." >&2
                exit 1
            fi
            ;;
        --kill-stale-palera1n|-ksp)
            source "$ROOT_DIR/lib/echo_mmo.sh"
            source "$ROOT_DIR/lib/kill_stale_palera1n.sh"
            kill_stale_palera1n
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $flag" >&2
            print_help >&2
            exit 1
            ;;
    esac
done
