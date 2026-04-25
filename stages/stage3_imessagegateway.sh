#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"

echo_mmo HEADER "Stage 3: iMessageGateway deployment"

echo_mmo INFO "Discovering phone WiFi IP..."
WIFI_IP=$(get_wifi_ip) || {
    echo_mmo FAILURE "Could not determine phone WiFi IP. Ensure the phone is on WiFi and plugged into USB." >&2
    exit 1
}
echo_mmo INFO "Phone WiFi IP: $WIFI_IP"

echo ""
echo_mmo INFO "In Claude Code, run:"
if [ "$SSH_PASS" = "alpine1" ]; then
    echo_mmo SUCCESS "  /setup-new-phone $WIFI_IP"
else
    echo_mmo SUCCESS "  /setup-new-phone $WIFI_IP $SSH_PASS"
fi
