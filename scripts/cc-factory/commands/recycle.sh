#!/bin/bash
# Recycle (archive and cleanup) a completed slot (Global Factory Architecture)

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

SLOT_ID="${1:-}"

if [[ -z "$SLOT_ID" ]]; then
    echo "Usage: ccf recycle <slot_id>"
    exit 1
fi

check_git_repo 2>/dev/null || { error "Not in a git repository"; exit 1; }

repo_id=$(get_repo_id)
repo_name=$(get_project_name)
SESSION_NAME=$(get_session_name "$SLOT_ID" "$repo_id")

log "Recycling slot $SLOT_ID for $repo_name..."

# Exit gracefully if running
if zellij_session_exists "$SESSION_NAME"; then
    log "Sending exit command..."
    zellij --session "$SESSION_NAME" action write-chars "/exit" 2>/dev/null || true
    sleep 1
    zellij --session "$SESSION_NAME" action write-chars "
" 2>/dev/null || true
    sleep 1
    
    zellij delete-session "$SESSION_NAME" 2>/dev/null || true
fi

# Archive worktree and delete branch (task is done)
archive_worktree "$SLOT_ID" "true"

# Update status
update_slot_status "$SLOT_ID" "idle" ""

success "Slot $SLOT_ID recycled and ready for new task"
