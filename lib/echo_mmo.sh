#!/usr/bin/env bash
# Prefixes every output line with `[MMO] ` so our own prints are easy to
# distinguish from palera1n / checkra1n / pymobiledevice3 output. Every
# script-originated print should go through this (exception: print_help,
# which is pure usage text and doesn't benefit from a tool tag).
#
# Usage:
#   echo_mmo "single line"                 # one line
#   echo_mmo "line 1" "line 2"             # each arg on its own line
#   cat <<EOF | echo_mmo                   # stdin mode: prefixes each line
#   banner line 1
#   banner line 2
#   EOF
#   echo_mmo "error text" >&2              # redirect to stderr normally
#
# Meant to be sourced. Do not execute directly.

echo_mmo() {
    local line
    if [ "$#" -gt 0 ]; then
        for line in "$@"; do
            printf '[MMO] %s\n' "$line"
        done
    else
        while IFS= read -r line || [ -n "$line" ]; do
            printf '[MMO] %s\n' "$line"
        done
    fi
}
