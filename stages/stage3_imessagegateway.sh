#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"
source "$ROOT_DIR/lib/run_setup_new_phone_skill.sh"

CURRENT_STEP="initializing"
trap 'echo_mmo FAILURE "Stage 3 aborted at step: $CURRENT_STEP" >&2' ERR

echo_mmo HEADER "Stage 3: iMessageGateway deployment"

# Stage 3 has no probes of its own: idempotency for the tweak deploy,
# LaunchDaemon, and Local Network grant lives inside the /setup-new-phone
# skill itself (dpkg/file-presence checks). This stage is a thin shell
# around `claude -p` and trusts the skill to skip already-done work.

CURRENT_STEP="WiFi IP discovery"
echo_mmo INFO "Discovering phone WiFi IP..."
WIFI_IP=$(get_wifi_ip) || {
    echo_mmo FAILURE "Could not determine phone WiFi IP. Ensure the phone is on WiFi and plugged into USB." >&2
    exit 1
}
echo_mmo INFO "Phone WiFi IP: $WIFI_IP"

CURRENT_STEP="/setup-new-phone skill invocation"
run_setup_new_phone_skill "$WIFI_IP" "$SSH_PASS"
