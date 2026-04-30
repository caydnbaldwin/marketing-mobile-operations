#!/usr/bin/env bash
# Checks whether the Sileo app is installed on the connected device via
# pymobiledevice3 over USB/lockdownd. Sileo's bundle identifier is
# org.coolstar.SileoStore and it installs as a System app.
#
# Why `apps query <bundle-id>` and not `apps list | grep`: `apps list`
# returns the full app catalog (~1 MB JSON for ~140 apps on iOS 15) and
# we observed the response intermittently coming back complete-by-byte-
# count but with org.coolstar.SileoStore *missing* under USB load — same
# response length, no Sileo entry, no error. This happened reproducibly
# in stage 2 verification right after `get_wifi_ip` released its iproxy
# tunnel. `apps query` returns metadata for just the requested bundle
# (a few KB) and isn't subject to the same truncation; testing shows it
# returns deterministically. We don't use ideviceinstaller because it
# intermittently fails with "Could not connect to lockdownd: Invalid
# HostID" on freshly-jailbroken devices.
#
# Three retries with 2s spacing as defense in depth (stage 2 verification
# runs right after Sileo install / OpenSSH install, both of which respring
# SpringBoard and momentarily disturb lockdownd). With apps query the
# retries should rarely if ever fire.
#
# Returns 0 if Sileo is installed, 1 otherwise. Requires jq on the host.
# Meant to be sourced. Do not execute directly.

verify_sileo_installed() {
    local i
    for i in 1 2 3; do
        if pymobiledevice3 apps query org.coolstar.SileoStore 2>/dev/null \
            | jq -e '."org.coolstar.SileoStore"' >/dev/null 2>&1; then
            return 0
        fi
        [ "$i" -lt 3 ] && sleep 2
    done
    return 1
}
