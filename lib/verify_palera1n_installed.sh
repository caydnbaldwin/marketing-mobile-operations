#!/usr/bin/env bash
# Returns 0 if the palera1n app is present on the connected iOS device, 1 otherwise.
# Silent — callers print SUCCESS/FAILURE if appropriate. This makes it safe to
# use as a probe (e.g. `if verify_palera1n_installed; then skip...`) without
# leaking spurious FAILURE lines on the not-found branch.
# Meant to be sourced. Do not execute directly.

verify_palera1n_installed() {
    ideviceinstaller list --all 2>/dev/null | grep -qi "palera1n"
}
