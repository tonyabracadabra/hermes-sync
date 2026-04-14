#!/bin/bash
# Send command to slot (Global Factory Architecture)

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

SLOT_ID="${1:-}"
COMMAND="${2:-}"

if [[ -z "$SLOT_ID" || -z "$COMMAND" ]]; then
    echo "Usage: ccf cmd <slot_id> <command>"
    echo "Example: ccf cmd 1 '/simplify'"
    exit 1
fi

check_git_repo 2>/dev/null || { error "Not in a git repository"; exit 1; }

repo_id=$(get_repo_id)
repo_name=$(get_project_name)
SESSION_NAME=$(get_session_name "$SLOT_ID" "$repo_id")

if ! zellij_session_exists "$SESSION_NAME"; then
    error "Slot $SLOT_ID is not running for $repo_name"
    exit 1
fi

log "Sending command to slot $SLOT_ID: $COMMAND"

zellij --session "$SESSION_NAME" action write-chars "$COMMAND"
zellij --session "$SESSION_NAME" action write-chars "
"

success "Command sent to slot $SLOT_ID"
