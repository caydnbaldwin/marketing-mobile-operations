#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"

echo_mmo "Stage 3: iMessageGateway deployment"

echo_mmo "Discovering phone WiFi IP..."
WIFI_IP=$(get_wifi_ip) || {
    echo_mmo "Could not determine phone WiFi IP. Ensure the phone is on WiFi and plugged into USB." >&2
    exit 1
}
echo_mmo "Phone WiFi IP: $WIFI_IP"

echo_mmo ""
echo_mmo "In Claude Code, run:"
if [ "$SSH_PASS" = "alpine1" ]; then
    echo_mmo "  /setup-new-phone $WIFI_IP"
else
    echo_mmo "  /setup-new-phone $WIFI_IP $SSH_PASS"
fi
