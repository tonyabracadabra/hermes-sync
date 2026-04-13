#!/bin/bash
# Send command to a running CC session

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/core.sh"

SLOT_ID="${1:-}"
COMMAND="${2:-}"

if [[ -z "$SLOT_ID" || -z "$COMMAND" ]]; then
    echo "Usage: ccf cmd <slot_id> <command>"
    echo "Examples:"
    echo "  ccf cmd 1 '/simplify'"
    echo "  ccf cmd 1 '/code-audit'"
    echo "  ccf cmd 1 'exit'"
    exit 1
fi

SESSION_NAME=$(get_session_name "$SLOT_ID")

if ! zellij_session_exists "$SESSION_NAME"; then
    error "Session $SESSION_NAME is not running"
    exit 1
fi

log "Sending to slot $SLOT_ID: $COMMAND"

zellij --session "$SESSION_NAME" action write-chars "$COMMAND"
sleep 0.5
zellij --session "$SESSION_NAME" action write-chars "
"

success "Command sent to slot $SLOT_ID"
