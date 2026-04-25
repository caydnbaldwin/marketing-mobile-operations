#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"
source "$ROOT_DIR/lib/verify_wifi_reachable.sh"
source "$ROOT_DIR/lib/verify_sileo_installed.sh"
source "$ROOT_DIR/lib/verify_ssh_as_mobile.sh"
source "$ROOT_DIR/lib/verify_sudo_as_mobile.sh"

echo_mmo HEADER "Stage 2 verification"

echo_mmo INFO "Discovering phone WiFi IP..."
WIFI_IP=$(get_wifi_ip) || {
    echo_mmo FAILURE "Could not determine phone WiFi IP. Ensure the phone is on WiFi and plugged into USB." >&2
    exit 1
}
echo_mmo INFO "Phone WiFi IP: $WIFI_IP"

# Prime ~/.ssh/known_hosts for this IP so the /setup-new-phone skill's
# plain `ssh mobile@<ip>` doesn't prompt on first contact. Wipe any stale
# entry first — phone IPs get reused as devices cycle through the fleet.
ssh-keygen -R "$WIFI_IP" >/dev/null 2>&1 || true
ssh-keyscan -T 5 "$WIFI_IP" 2>/dev/null >> ~/.ssh/known_hosts || true

wifi_ok=false; sileo_ok=false; ssh_ok=false; sudo_ok=false; all_ok=true
verify_wifi_reachable "$WIFI_IP"  && wifi_ok=true  || all_ok=false
verify_sileo_installed            && sileo_ok=true || all_ok=false
verify_ssh_as_mobile "$WIFI_IP"   && ssh_ok=true   || all_ok=false
verify_sudo_as_mobile "$WIFI_IP"  && sudo_ok=true  || all_ok=false

wifi_status="FAIL";    $wifi_ok   && wifi_status="OK"
sileo_status="FAIL";   $sileo_ok  && sileo_status="OK"
ssh_status="FAIL";     $ssh_ok    && ssh_status="OK"
sudo_status="FAIL";    $sudo_ok   && sudo_status="OK"

cat <<EOF | echo_mmo INFO

============================================
  Stage 2 verification ($WIFI_IP)
============================================
EOF
printf '[MMO] [INFO]   %-26s %s\n' "WiFi (${WIFI_SSID}):"    "$wifi_status"
printf '[MMO] [INFO]   %-26s %s\n' "Sileo:"                  "$sileo_status"
printf '[MMO] [INFO]   %-26s %s\n' "OpenSSH (mobile@):"      "$ssh_status"
printf '[MMO] [INFO]   %-26s %s\n' "sudo (mobile -> root):"  "$sudo_status"
echo_mmo INFO "============================================"

if $all_ok; then
    echo_mmo SUCCESS "All checks passed."
else
    echo_mmo FAILURE "One or more checks failed." >&2
    exit 1
fi
