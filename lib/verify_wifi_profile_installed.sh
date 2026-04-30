#!/usr/bin/env bash
# Returns 0 if the Stage2 WiFi configuration profile is currently INSTALLED
# and active on the device (i.e. the operator has already tapped Install
# in Settings > General > VPN & Device Management on a previous run), 1
# otherwise. Distinguishes "installed" from merely "pushed but pending."
#
# How: `pymobiledevice3 profile list` returns
#   .ProfileManifest["com.stage2.wifi"].IsActive == true|false
# A pushed-but-not-installed profile sits as a "Downloaded Profile" with
# IsActive false until the operator confirms in Settings; once they tap
# Install, IsActive flips true and the device joins the WiFi.
#
# Why this matters: stage 2's install-prompt skip used to depend on
# (verify_wifi_profile_pushed AND get_wifi_ip), but get_wifi_ip needs
# OpenSSH on port 22 — which isn't installed yet at that point in the
# flow. So the skip never fired on re-runs and the operator got prompted
# even when the phone was already on WiFi. IsActive is the right
# pre-OpenSSH discriminator: it's a lockdownd-only field, no SSH needed.
#
# Silent — callers print SKIP/INFO if appropriate. Requires jq on the host.
# Meant to be sourced. Do not execute directly.

verify_wifi_profile_installed() {
    pymobiledevice3 profile list 2>/dev/null \
        | jq -e '.ProfileManifest["com.stage2.wifi"].IsActive == true' >/dev/null 2>&1
}
