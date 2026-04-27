#!/usr/bin/env bash
# Invokes the /setup-new-phone Claude skill non-interactively via `claude -p`.
# Two-phase flow with an operator pause for the SIM swap:
#   1. Deploy pass: `/setup-new-phone <ip> <pass>` — capture session_id.
#   2. Operator inserts SIM, toggles iMessage off/on, waits for phone number.
#   3. Reverify pass: `claude --resume <session_id> -p "reverify"` — same
#      session so the skill keeps context (knows which phone, what it just did).
#
# Output is streamed via `--output-format stream-json --verbose` and rendered
# through jq, because default `-p` text output buffers until the whole pass
# completes (minutes). `--dangerously-skip-permissions` is required because
# the skill issues SSH/scp/sudo tool calls; without it each one would hang
# waiting for an approval prompt that never comes.
#
# Args: <ip> [password=alpine1]
# Returns: 0 if both passes succeed; 1 if claude/jq missing or session_id
#          can't be captured. Pipeline failures propagate via pipefail.
# Requires echo_mmo to be in scope (source lib/echo_mmo.sh first).
#
# Meant to be sourced. Do not execute directly.

run_setup_new_phone_skill() {
    local ip="${1:?run_setup_new_phone_skill: ip required}"
    local pass="${2:-alpine1}"

    if ! command -v claude >/dev/null 2>&1; then
        echo_mmo FAILURE "claude CLI not found in PATH. Install Claude Code and retry." >&2
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo_mmo FAILURE "jq not found in PATH. Run: brew install jq" >&2
        return 1
    fi

    local display_filter='
        if .type == "assistant" then
            (.message.content // [] | map(
                if .type == "text" then .text
                elif .type == "tool_use" then "→ " + .name + " " + (.input | tostring | .[0:240])
                else empty end
            ) | map(select(. != "")) | join("\n"))
        elif .type == "user" then
            (.message.content // [] | map(
                if .type == "tool_result" then
                    "← " + (
                        if (.content | type) == "string" then .content
                        else (.content // [] | map(.text // "") | join(""))
                        end | gsub("\n"; " ") | .[0:240]
                    )
                else empty end
            ) | map(select(. != "")) | join("\n"))
        elif .type == "result" then "[done] " + ((.result // .subtype // "") | tostring)
        else empty end
    '

    local stream_file
    stream_file=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$stream_file'" RETURN

    echo_mmo INFO "Pass 1/2: deploying tweak via /setup-new-phone (output streams below)."
    echo_mmo INFO "You can watch but not intervene; Ctrl+C aborts."
    echo ""

    claude --dangerously-skip-permissions \
        --output-format stream-json \
        --verbose \
        -p "/setup-new-phone $ip $pass" \
    | tee "$stream_file" \
    | jq -r "$display_filter"

    local session_id
    session_id=$(jq -r 'select(.type == "system" and .subtype == "init") | .session_id' "$stream_file" | head -n 1)
    if [ -z "$session_id" ] || [ "$session_id" = "null" ]; then
        echo_mmo FAILURE "Could not capture Claude session_id from pass 1 — cannot resume for reverify." >&2
        return 1
    fi

    echo ""
    echo_mmo SUCCESS "Pass 1 complete. Session: $session_id"
    echo ""
    read -rp "[MMO] Insert SIM, toggle iMessage off then on, wait for the phone number to register, then press Enter to reverify... "
    echo ""

    echo_mmo INFO "Pass 2/2: reverify (resuming session $session_id)."
    echo ""

    claude --dangerously-skip-permissions \
        --resume "$session_id" \
        --output-format stream-json \
        --verbose \
        -p "reverify" \
    | jq -r "$display_filter"
}
