#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=.env
source "$ROOT_DIR/.env"
source "$ROOT_DIR/lib/echo_mmo.sh"
source "$ROOT_DIR/lib/verify_device_reachable.sh"
source "$ROOT_DIR/lib/push_wifi_profile.sh"
source "$ROOT_DIR/lib/verify_wifi_profile_pushed.sh"
source "$ROOT_DIR/lib/verify_wifi_profile_installed.sh"
source "$ROOT_DIR/lib/get_wifi_ip.sh"
source "$ROOT_DIR/lib/run_via_dropbear.sh"
source "$ROOT_DIR/lib/verify_sileo_installed.sh"
source "$ROOT_DIR/lib/verify_dropbear_auth.sh"
source "$ROOT_DIR/lib/launch_sileo_app.sh"
source "$ROOT_DIR/lib/launch_palera1n_loader.sh"
source "$ROOT_DIR/lib/install_openssh_via_dropbear.sh"
source "$ROOT_DIR/lib/verify_openssh_installed.sh"
source "$ROOT_DIR/lib/trigger_local_network_prompt.sh"
source "$ROOT_DIR/lib/verify_local_network_granted.sh"
source "$ROOT_DIR/lib/mark_local_network_granted.sh"

CURRENT_STEP="initializing"
trap 'echo_mmo FAILURE "Stage 2 aborted at step: $CURRENT_STEP" >&2' ERR

echo_mmo HEADER "Stage 2: WiFi, Sileo, OpenSSH, Local Network"

CURRENT_STEP="device reachability precheck"
verify_device_reachable

sleep 2

# --- Manual bridge 1: WiFi profile install -----------------------------------
# Skip the push if the profile is already on the device. Skip the operator
# tap-pause if the profile is currently INSTALLED (IsActive=true in
# lockdownd's ProfileManifest) — that's a pre-OpenSSH-friendly proxy for
# "operator already tapped Install on a previous run, phone joined WiFi."
# The previous get_wifi_ip-based check needed OpenSSH on port 22, which
# isn't installed yet at this point, so it never fired on re-runs.
CURRENT_STEP="WiFi profile push"
if verify_wifi_profile_pushed 2>/dev/null; then
    echo_mmo SKIP "WiFi profile already pushed — skipping push"
else
    echo_mmo INFO "Pushing WiFi configuration profile to device..."
    push_wifi_profile
fi

CURRENT_STEP="WiFi profile install (operator tap)"
if verify_wifi_profile_installed 2>/dev/null; then
    echo_mmo SKIP "WiFi profile already installed (IsActive=true) — skipping operator tap"
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
SILEO_INSTALL_RAN=0
if verify_sileo_installed 2>/dev/null && verify_dropbear_auth 2>/dev/null; then
    echo_mmo SKIP "Sileo already installed and password matches \$SSH_PASS — skipping"
else
    # Best-effort attempt to foreground the palera1n loader for the
    # operator. DVT-launched apps historically come up in the background
    # only, so step 1 below ("Open the palera1n app") stays as a fallback.
    echo_mmo INFO "Attempting to open the palera1n loader on the phone..."
    launch_palera1n_loader || true

    cat <<EOF | echo_mmo INFO

============================================
  On the iPhone:
  1. Open the palera1n app (if not already foregrounded)
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
    SILEO_INSTALL_RAN=1
fi

# Only auto-launch Sileo if the operator just installed it. The first
# launch surfaces iOS's WLAN-and-cellular data permission prompt for
# Sileo; the operator needs to approve so Sileo can reach its source
# repos. On a re-run (Sileo skip path) the prompt has already been
# answered and re-launching is just visual noise.
if [ "$SILEO_INSTALL_RAN" = 1 ]; then
    CURRENT_STEP="Sileo launch (cellular/WLAN permission prompt)"
    echo_mmo INFO "Opening Sileo on the phone..."
    launch_sileo_app || true
fi

# --- Automated bridge 3: install OpenSSH via dropbear over USB ---------------
CURRENT_STEP="OpenSSH install via dropbear"
if verify_openssh_installed 2>/dev/null; then
    echo_mmo SKIP "OpenSSH already installed on phone — skipping"
else
    echo_mmo INFO "Installing OpenSSH via Procursus apt over dropbear (USB)..."
    install_openssh_via_dropbear
fi

# --- Semi-automated bridge 4: launch Messages so iOS surfaces the prompt -----
# Skip if the .mmo_local_network_granted marker is already on the phone.
# The actual iOS grant lives in an opaque binary plist
# (com.apple.networkextension.plist), so we use the marker as our proxy:
# dropped after the operator confirms the prompt the first time, checked
# every subsequent run. If the operator later revoked the grant in
# Settings, stage 3 will fail with EHOSTUNREACH — recovery is to delete
# the marker (`ssh mobile@<phone> rm /var/mobile/Library/Preferences/.mmo_local_network_granted`)
# and re-run stage 2.
CURRENT_STEP="Local Network prompt trigger"
if verify_local_network_granted 2>/dev/null; then
    echo_mmo SKIP "Local Network already granted — skipping Messages launch + prompt"
else
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
    mark_local_network_granted || true
fi
