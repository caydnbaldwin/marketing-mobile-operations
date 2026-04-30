#!/usr/bin/env bash
# Prints the run.sh CLI help text to stdout.
# Meant to be sourced. Do not execute directly.

print_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION...]

With no option, runs the full pipeline:
    stage1 -> stage1_verification -> stage2 -> stage2_verification -> stage3 -> stage3_verification

Stage flags can be chained; they run in the order given and abort on the
first failure. Examples:
    $(basename "$0") -s1 -s1v -s2          # run s1, s1v, s2 in sequence
    $(basename "$0") -s1/v -s2/v           # same as: -s1 -s1v -s2 -s2v
    $(basename "$0") -s2/v -s3/v           # everything past stage 1, with verifies

Stages (full workflows):
    -s1,  --stage1                     Jailbreak via palera1n
    -s1v, --stage1-verification        Verify stage 1 end state
    -s2,  --stage2                     Install WiFi profile, Sileo, OpenSSH (manual bridges)
    -s2v, --stage2-verification        Verify stage 2 end state (WiFi, Sileo, SSH, sudo)
    -s3,  --stage3                     Auto-invoke /setup-new-phone skill via claude -p
    -s3v, --stage3-verification        Verify phone number registered + print setup summary

Stage shorthand (expands to "main + verify" for that stage):
    -s1/v                              Same as: -s1 -s1v
    -s2/v                              Same as: -s2 -s2v
    -s3/v                              Same as: -s3 -s3v

Atomic operations (individual lib/ functions):
    -vpi, --verify-palera1n-installed  One-shot check for the palera1n app on the device
    -ksp, --kill-stale-palera1n        Kill any leftover palera1n/checkra1n processes (prompts for sudo)
    -sdl, --set-device-language        Set device UI language + locale via lockdownd (defaults: en en_US)
                                       Optional args: -sdl <lang> <locale>, e.g. -sdl es es_ES
    -rsnps, --run-setup-new-phone-skill
                                       Invoke the /setup-new-phone Claude skill via claude -p
                                       Optional args: -rsnps <ip> <pass> (defaults: discover IP, \$SSH_PASS)

Other:
    -h,   --help                       Show this help
EOF
}
