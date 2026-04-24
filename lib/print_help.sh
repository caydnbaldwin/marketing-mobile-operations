#!/usr/bin/env bash
# Prints the run.sh CLI help text to stdout.
# Meant to be sourced. Do not execute directly.

print_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

With no option, runs stage 1 (jailbreak) then stage 2 (Sileo + OpenSSH).

Stages (full workflows):
    --stage1                          Run only stage 1 (jailbreak)
    --stage2                          Run only stage 2 (WiFi + Sileo + OpenSSH)

Atomic operations (individual lib/ functions):
    --verify-palera1n-installed       Check whether palera1n is installed on the device

Other:
    -h, --help                        Show this help
EOF
}
