#!/usr/bin/env bash
# Prefixes every output line with `[MMO] [<TYPE>] ` so script-originated
# output is easy to distinguish from palera1n / checkra1n / pymobiledevice3
# output, AND so each line is tagged with its semantic role. Every
# script-originated print should go through this (exception: print_help,
# which is pure usage text and doesn't benefit from a tool tag).
#
# Type is required and must be the first argument. Conventional types:
#   HEADER   — stage banner, e.g. "Stage 1: Jailbreak (palera1n)"
#   INFO     — neutral progress / status line
#   SUCCESS  — positive confirmation ("palera1n installed", "All checks passed")
#   WARNING  — non-fatal: long poll heartbeat, transient retry, soft anomaly.
#              Use for "the thing isn't done yet, but we're not giving up."
#   FAILURE  — error path; usually paired with `>&2`
# Other strings are accepted verbatim (printed in the brackets) but the
# five above are the canonical set across the project.
#
# Colors (24-bit ANSI, auto-disabled when stdout is not a TTY, or when
# NO_COLOR=1 is set per https://no-color.org). The [MMO] prefix is the
# project indigo (#402da3); type tags use semantic colors:
#   HEADER   #00d7ff (cyan)
#   INFO     #a8a8a8 (gray)
#   SUCCESS  #5fd700 (green)
#   WARNING  #ffaf00 (amber)
#   FAILURE  #ff5f5f (red)
# The message body itself is left in the terminal's default color —
# coloring only the tags keeps long messages readable.
#
# Usage:
#   echo_mmo INFO    "single line"
#   echo_mmo INFO    "line 1" "line 2"             # each arg on its own line
#   echo_mmo FAILURE "boom" >&2                    # redirect to stderr
#   echo_mmo WARNING "still waiting (30s elapsed)" # poll heartbeat
#   cat <<EOF | echo_mmo INFO                      # stdin mode
#   banner line 1
#   banner line 2
#   EOF
#
# For purely visual spacing (a blank line between groups), prefer plain
# `echo ""` over `echo_mmo INFO ""` so the spacer doesn't carry a tag.
#
# Meant to be sourced. Do not execute directly.

echo_mmo() {
    local type="$1"
    shift

    local mmo_color="" type_color="" reset=""
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        mmo_color=$'\033[38;2;64;45;163m'    # #402da3 indigo
        reset=$'\033[0m'
        case "$type" in
            HEADER)  type_color=$'\033[38;2;0;215;255m'   ;;  # #00d7ff cyan
            INFO)    type_color=$'\033[38;2;168;168;168m' ;;  # #a8a8a8 gray
            SUCCESS) type_color=$'\033[38;2;95;215;0m'    ;;  # #5fd700 green
            WARNING) type_color=$'\033[38;2;255;175;0m'   ;;  # #ffaf00 amber
            FAILURE) type_color=$'\033[38;2;255;95;95m'   ;;  # #ff5f5f red
            *)       type_color="" ;;                          # unknown: no color
        esac
    fi

    local prefix="${mmo_color}[MMO]${reset} ${type_color}[${type}]${reset}"

    local line
    if [ "$#" -gt 0 ]; then
        for line in "$@"; do
            printf '%s %s\n' "$prefix" "$line"
        done
    else
        while IFS= read -r line || [ -n "$line" ]; do
            printf '%s %s\n' "$prefix" "$line"
        done
    fi
}
