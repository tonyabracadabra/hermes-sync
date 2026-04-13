#!/bin/bash
# Attach to a CC session

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

SLOT_ID="${1:-}"

if [[ -z "$SLOT_ID" ]]; then
    echo "Usage: ccf attach <slot_id>"
    echo "Example: ccf attach 1"
    exit 1
fi

SESSION_NAME=$(get_session_name "$SLOT_ID")

if ! zellij_session_exists "$SESSION_NAME"; then
    error "Session $SESSION_NAME is not running"
    log "Use 'ccf start $SLOT_ID <description>' to start"
    exit 1
fi

log "Attaching to slot $SLOT_ID..."
log "Press Ctrl+O then D to detach (session keeps running)"
echo ""

zellij attach "$SESSION_NAME"
