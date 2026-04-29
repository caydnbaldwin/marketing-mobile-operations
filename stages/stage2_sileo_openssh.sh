#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/verify_device_reachable.sh"
source "$ROOT_DIR/lib/push_wifi_profile.sh"
source "$ROOT_DIR/lib/verify_wifi_profile_pushed.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"
source "$ROOT_DIR/lib/run_via_dropbear.sh"
source "$ROOT_DIR/lib/verify_sileo_installed.sh"
source "$ROOT_DIR/lib/verify_dropbear_auth.sh"
source "$ROOT_DIR/lib/launch_sileo_app.sh"
source "$ROOT_DIR/lib/install_openssh_via_dropbear.sh"
source "$ROOT_DIR/lib/verify_openssh_installed.sh"
source "$ROOT_DIR/lib/trigger_local_network_prompt.sh"

CURRENT_STEP="initializing"
trap 'echo_mmo FAILURE "Stage 2 aborted at step: $CURRENT_STEP" >&2' ERR

echo_mmo HEADER "Stage 2: WiFi, Sileo, OpenSSH, Local Network"

CURRENT_STEP="device reachability precheck"
verify_device_reachable

sleep 2

# --- Manual bridge 1: WiFi profile install -----------------------------------
# Skip the push if the profile is already on the device. Skip the operator
# tap-pause if both the profile is pushed AND get_wifi_ip succeeds (proves
# the operator already tapped Install at some point — phone is on WiFi).
# The get_wifi_ip path runs through OpenSSH on port 22, so this skip path
# only fully fires after a previous full stage 2 has reached step 4.
CURRENT_STEP="WiFi profile push"
if verify_wifi_profile_pushed 2>/dev/null; then
    echo_mmo SKIP "WiFi profile already pushed — skipping push"
else
    echo_mmo INFO "Pushing WiFi configuration profile to device..."
    push_wifi_profile
fi

CURRENT_STEP="WiFi profile install (operator tap)"
if verify_wifi_profile_pushed 2>/dev/null && get_wifi_ip >/dev/null 2>&1; then
    echo_mmo SKIP "WiFi already installed and joined — skipping operator tap"
else
    cat <<EOF | echo_mmo INFO

============================================
  On the iPhone:
  Settings > General > VPN & Device Management
  Tap 'Stage2 WiFi' > Install
  The device will auto-join: ${WIFI_SSID}
============================================
EOF
    read -rp "[MMO] Press Enter once the device is on WiFi... "
fi

# --- Manual bridge 2: Install Sileo (this sets mobile's password) ------------
# Dual-probe: Sileo on disk AND mobile's password matches current $SSH_PASS.
# Sileo presence alone isn't enough — a stale password from a prior install
# would let us skip here and then fail opaquely at the OpenSSH step.
CURRENT_STEP="Sileo install (operator tap + password set)"
if verify_sileo_installed 2>/dev/null && verify_dropbear_auth 2>/dev/null; then
    echo_mmo SKIP "Sileo already installed and password matches \$SSH_PASS — skipping"
else
    cat <<EOF | echo_mmo INFO

============================================
  On the iPhone:
  1. Open the palera1n app
  2. Tap 'Install Sileo'
  3. Set password:     ${SSH_PASS}
  4. Confirm password: ${SSH_PASS}
  Wait for Sileo to finish installing.
  (Sets the password on the 'mobile' user;
   the next two steps SSH in as that user
   over dropbear/USB to finish setup.)
============================================
EOF
    read -rp "[MMO] Press Enter when Sileo is installed and password is set... "
fi

# Always run: launching an already-foregrounded app is a cheap no-op, and
# this is a UX nicety (warm Sileo's source indexes) rather than a step
# anything downstream depends on.
CURRENT_STEP="Sileo launch (UX warm-up)"
echo_mmo INFO "Opening Sileo on the phone..."
launch_sileo_app || true

# --- Automated bridge 3: install OpenSSH via dropbear over USB ---------------
CURRENT_STEP="OpenSSH install via dropbear"
if verify_openssh_installed 2>/dev/null; then
    echo_mmo SKIP "OpenSSH already installed on phone — skipping"
else
    echo_mmo INFO "Installing OpenSSH via Procursus apt over dropbear (USB)..."
    install_openssh_via_dropbear
fi

# --- Semi-automated bridge 4: launch Messages so iOS surfaces the prompt -----
# Always re-trigger: the Local Network grant lives in a binary plist
# (com.apple.networkextension.plist) that isn't safely shell-readable, so
# there's no clean probe for "already granted." iOS no-ops the modal when
# the grant is already in place, so re-triggering is harmless — the
# operator just presses Enter past an absent prompt.
CURRENT_STEP="Local Network prompt trigger"
echo_mmo INFO "Launching Messages on the phone over dropbear..."
trigger_local_network_prompt

cat <<EOF | echo_mmo INFO

============================================
  On the iPhone:
  Approve the 'Local Network' permission
  prompt for Messages (if shown).
  (Without it the iMessageGateway tweak
   later fails with EHOSTUNREACH. If the
   prompt doesn't appear, permission was
   already granted — just press Enter.)
============================================
EOF
read -rp "[MMO] Press Enter once the Local Network prompt is approved (or absent)... "
