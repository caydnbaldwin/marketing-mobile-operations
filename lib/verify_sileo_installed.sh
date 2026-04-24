#!/usr/bin/env bash
# Checks whether the Sileo app is installed on the connected device via
# pymobiledevice3 over USB/lockdownd. Uses pymobiledevice3 rather than
# ideviceinstaller because ideviceinstaller intermittently fails with
# "Could not connect to lockdownd: Invalid HostID" on freshly-jailbroken
# devices (pairing-record mismatch); pymobiledevice3 handles pairing
# differently and doesn't hit this. Sileo's bundle identifier is
# org.coolstar.SileoStore and it installs as a System app.
#
# Returns 0 if Sileo is installed, 1 otherwise.
# Meant to be sourced. Do not execute directly.

verify_sileo_installed() {
    pymobiledevice3 apps list 2>/dev/null | grep -q '"org.coolstar.SileoStore"'
}
