#!/bin/bash
# Recycle (archive and cleanup) a completed slot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/core.sh"

SLOT_ID="${1:-}"

if [[ -z "$SLOT_ID" ]]; then
    echo "Usage: ccf recycle <slot_id>"
    exit 1
fi

SESSION_NAME=$(get_session_name "$SLOT_ID")

log "Recycling slot $SLOT_ID..."

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

# Archive worktree
archive_worktree "$SLOT_ID"

# Update status
update_slot_status "$SLOT_ID" "idle" ""

success "Slot $SLOT_ID recycled and ready for new task"
