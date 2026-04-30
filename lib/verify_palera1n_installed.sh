#!/usr/bin/env bash
# Returns 0 if the palera1n loader app is actually present and launchable
# on the connected iOS device, 1 otherwise. Silent — callers print
# SUCCESS/FAILURE if appropriate. This makes it safe to use as a probe
# (e.g. `if verify_palera1n_installed; then skip...`) without leaking
# spurious FAILURE lines on the not-found branch.
#
# Why dvt launch and not apps list / springboard icon / dvt applist:
# mobileinstallationd's app index, SpringBoard's icon cache, and DVT's
# own applist all persist a registration after the bundle itself is gone.
# A phone that used to have palera1n and was later wiped or chain-booted
# back to stock will still show the loader in every metadata cache, with
# valid Path, valid icon PNG, valid display name — even though the binary
# at /cores/binpack/Applications/palera1nLoader.app is unreachable
# (binpack volume not mounted post-stock-boot). The only probe that
# actually touches the binary is dvt launch: it tries to exec the bundle,
# and surfaces a clear failure (exit 1 plus
# "Failed to launch process with bundle identifier" in output) when the
# binary is missing.
#
# Two-step verification, both required for a "yes":
#   1. dvt launch --suspended exits 0.
#   2. dvt process-id-for-bundle-id returns a numeric PID for the bundle.
# Step 2 defends against a transient iOS-side state we observed once where
# launch returned success without actually exec'ing the binary (no PID
# afterward, no app icon on the phone). Without the PID cross-check that
# spurious success would propagate as a false positive into stage 1's
# top-level guard and stage 1 verification, skipping a needed jailbreak.
#
# On a confirmed real launch the loader is left as a suspended process —
# we dvt-kill it before returning so we don't leave a stalled palera1n
# loader between probes (the polling loop in wait_for_palera1n_installed
# would otherwise leave one behind even with --kill-existing churning
# prior instances).
#
# Requires the developer disk image to be mounted; this function calls
# `pymobiledevice3 mounter auto-mount` first (idempotent — no-op if
# already mounted, ~ms after the first call in a session).
#
# Requires pymobiledevice3 on the host. No phone-side dependencies, no
# SSH (works pre-Sileo, pre-OpenSSH).
# Meant to be sourced. Do not execute directly.

verify_palera1n_installed() {
    # `--version 15.5`: this project targets iPhone 6s on iOS 15.x. Xcode's
    # DeviceSupport ships DDIs for 15.0/15.2/15.4/15.5 but not 15.8. Plain
    # auto-mount tries to fetch+save 15.8 into Xcode's protected directory,
    # which fails on permissions (and silently returns exit 0). iOS DDIs
    # are compatible across minor versions — pinning 15.5 mounts cleanly
    # against any iOS 15.x device. If you re-target newer iOS, bump this
    # to whatever's in /Applications/Xcode.app/.../DeviceSupport/.
    pymobiledevice3 mounter auto-mount --version 15.5 >/dev/null 2>&1

    if ! pymobiledevice3 developer dvt launch --suspended in.palera.loader >/dev/null 2>&1; then
        return 1
    fi

    local pid
    pid=$(pymobiledevice3 developer dvt process-id-for-bundle-id in.palera.loader 2>/dev/null | tr -dc '0-9')
    if [ -z "$pid" ]; then
        return 1
    fi

    pymobiledevice3 developer dvt kill "$pid" >/dev/null 2>&1 || true
    return 0
}
