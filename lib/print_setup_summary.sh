#!/usr/bin/env bash
# Renders the post-stage-3 readout: IP, SSH password, phone number, success.
# Phone number is queried via get_phone_number (pymobiledevice3 lockdownd).
# Prints "(unavailable)" and returns 1 if the number isn't registered yet — the
# caller (typically stage3_verification) decides whether that's a hard failure.
#
# Args: <ip> <pass>
# Returns: 0 if phone number was found; 1 if it wasn't.
# Requires echo_mmo and get_phone_number to be in scope.
#
# Meant to be sourced. Do not execute directly.

print_setup_summary() {
    local ip="${1:?print_setup_summary: ip required}"
    local pass="${2:?print_setup_summary: pass required}"
    local number rc=0

    if number=$(get_phone_number); then
        :
    else
        number="(unavailable)"
        rc=1
    fi

    echo ""
    if [ "$rc" -eq 0 ]; then
        echo_mmo SUCCESS "Phone setup complete"
    else
        echo_mmo WARNING "Phone setup readout (phone number not yet registered)"
    fi
    echo_mmo INFO "  IP address:    $ip"
    echo_mmo INFO "  SSH password:  $pass"
    echo_mmo INFO "  Phone number:  $number"

    return "$rc"
}
