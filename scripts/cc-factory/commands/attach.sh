#!/bin/bash
# Attach to slot interactively (Global Factory Architecture)

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

SLOT_ID="${1:-}"

if [[ -z "$SLOT_ID" ]]; then
    echo "Usage: ccf attach <slot_id>"
    exit 1
fi

check_git_repo 2>/dev/null || { error "Not in a git repository"; exit 1; }

repo_id=$(get_repo_id)
repo_name=$(get_project_name)
SESSION_NAME=$(get_session_name "$SLOT_ID" "$repo_id")

if ! zellij_session_exists "$SESSION_NAME"; then
    error "Slot $SLOT_ID is not running for $repo_name"
    log "Start it first with: ccf start $SLOT_ID '<task description>'"
    exit 1
fi

log "Attaching to slot $SLOT_ID ($repo_name)..."
log "Press Ctrl+O to detach (or 'Ctrl+b d' if using tmux-like bindings)"
echo ""

exec zellij attach "$SESSION_NAME"
