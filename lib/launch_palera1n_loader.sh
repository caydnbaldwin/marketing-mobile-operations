#!/usr/bin/env bash
# Attempts to launch the palera1n loader on the phone via DVT (Apple's
# Instruments protocol over USB), so the operator doesn't have to tap the
# home-screen icon manually. Idempotent — `--kill-existing` (the default)
# replaces any prior instance.
#
# Caveat (CLAUDE.md documents this): historically DVT launches in the
# *background* for measurement, not foreground for UI, so the loader may
# spawn but never visibly come to the front. The loader has no
# CFBundleURLTypes either, so a `uiopen palera1n://` style hop isn't
# available pre-Sileo. This function makes the *attempt*; if iOS doesn't
# foreground it, the manual "Open the palera1n app" instruction in stage 2
# is still the operator's path. Worth re-evaluating against newer
# pymobiledevice3 releases — the foregrounding behavior is an Apple-side
# choice that could change.
#
# Why we know we can at least *spawn* the loader: verify_palera1n_installed
# uses the same `dvt launch` machinery (with --suspended) as a probe.
# This function uses the non-suspended variant — same channel, same
# requirements, just letting the process run rather than parking it.
#
# Requires the developer disk image to be mounted; this function calls
# `pymobiledevice3 mounter auto-mount` first (idempotent — no-op if
# already mounted).
#
# Returns 0 on a successful launch attempt (process spawned), 1 if
# pymobiledevice3 couldn't reach the device or the launch errored. A
# zero-return does NOT prove the app is foregrounded — only that it
# started.
#
# Meant to be sourced. Do not execute directly.

launch_palera1n_loader() {
    # See verify_palera1n_installed.sh for why --version 15.5 is pinned.
    pymobiledevice3 mounter auto-mount --version 15.5 >/dev/null 2>&1
    pymobiledevice3 developer dvt launch in.palera.loader >/dev/null 2>&1
}
