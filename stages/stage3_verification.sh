#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"
source "$ROOT_DIR/lib/get_phone_number.sh"
source "$ROOT_DIR/lib/print_setup_summary.sh"

echo_mmo HEADER "Stage 3 verification: phone number registration + summary"

echo_mmo INFO "Discovering phone WiFi IP..."
WIFI_IP=$(get_wifi_ip) || {
    echo_mmo FAILURE "Could not determine phone WiFi IP. Ensure the phone is on WiFi and plugged into USB." >&2
    exit 1
}

if ! print_setup_summary "$WIFI_IP" "$SSH_PASS"; then
    echo ""
    echo_mmo FAILURE "Phone number not yet registered. Insert SIM, toggle iMessage off/on, wait for the number to register, then re-run \`mmo -s3v\`." >&2
    exit 1
fi
