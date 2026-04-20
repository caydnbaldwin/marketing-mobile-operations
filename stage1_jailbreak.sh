#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

if [[ "${1:-}" == "--verify-palera1n" ]]; then
    systemctl start usbmuxd 2>/dev/null || true
    sleep 3
    if ideviceinstaller -l -o list_all | grep -qi "palera1n"; then
        echo "palera1n successfully installed on device."
    else
        echo "palera1n not found on device." >&2
        exit 1
    fi
    exit 0
fi

systemctl stop usbmuxd 2>/dev/null || true

palera1n -f -c
palera1n -f

systemctl start usbmuxd
sleep 3

if ideviceinstaller -l -o list_all | grep -qi "palera1n"; then
    echo "palera1n successfully installed on device."
else
    echo "palera1n not found on device." >&2
    exit 1
fi
