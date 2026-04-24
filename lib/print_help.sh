#!/usr/bin/env bash
# Prints the run.sh CLI help text to stdout.
# Meant to be sourced. Do not execute directly.

print_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

With no option, runs the full pipeline:
    stage1 -> stage1_verification -> stage2 -> stage2_verification -> stage3

Stages (full workflows):
    -s1,  --stage1                     Jailbreak via palera1n
    -s1v, --stage1-verification        Verify stage 1 end state
    -s2,  --stage2                     Install WiFi profile, Sileo, OpenSSH (manual bridges)
    -s2v, --stage2-verification        Verify stage 2 end state (WiFi, Sileo, SSH, sudo)
    -s3,  --stage3                     Print /setup-new-phone handoff

Atomic operations (individual lib/ functions):
    -vpi, --verify-palera1n-installed  One-shot check for the palera1n app on the device
    -ksp, --kill-stale-palera1n        Kill any leftover palera1n/checkra1n processes (prompts for sudo)

Other:
    -h,   --help                       Show this help
EOF
}
