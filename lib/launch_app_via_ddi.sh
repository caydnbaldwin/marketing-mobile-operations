#!/usr/bin/env bash
# Launches an app on the connected iPhone by bundle ID, via Apple's DVT
# instrumentation interface (`pymobiledevice3 developer dvt launch`). Used in
# stage 2 to open the palera1n loader before the operator's manual Sileo-
# install tap — pre-Sileo, dropbear can't auth (master.passwd is empty), so
# the existing `uiopen`-via-dropbear path is unavailable. DDI works pre-Sileo
# because lockdownd serves it over plain USB without needing master.passwd.
#
# Mounts the Developer Disk Image first if needed via `mounter auto-mount`.
# DDI mount is per-boot on the device and idempotent across calls within a
# session, so on second-and-later launches in the same stage 2 run, the mount
# step is a fast no-op. First-ever mount on a Mac downloads the matching DDI
# (~hundreds of MB) and caches it under pymobiledevice3's data dir.
#
# Best-effort: emits a WARNING and returns 1 on any failure (couldn't mount,
# couldn't launch). Callers in stage 2 should fall back to telling the
# operator to open the app manually rather than aborting.
#
# Args: <bundle_id>
# Returns: 0 on launch success, 1 on any failure.
# Requires echo_mmo to be in scope.
# Meant to be sourced. Do not execute directly.

launch_app_via_ddi() {
    local bundle_id="${1:?launch_app_via_ddi: bundle_id required}"

    if ! pymobiledevice3 mounter list 2>/dev/null | grep -q -i "developer"; then
        echo_mmo INFO "Mounting Developer Disk Image (one-time download per iOS version)..."
        if ! pymobiledevice3 mounter auto-mount >/dev/null 2>&1; then
            echo_mmo WARNING "DDI mount failed — open the app manually."
            return 1
        fi
    fi

    if pymobiledevice3 developer dvt launch "$bundle_id" >/dev/null 2>&1; then
        echo_mmo SUCCESS "Launched $bundle_id on the phone."
        return 0
    fi
    echo_mmo WARNING "Could not launch $bundle_id via DDI — open the app manually."
    return 1
}
