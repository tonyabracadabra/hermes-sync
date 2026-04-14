#!/bin/bash
# Start a new CC task in a specific slot (Global Factory Architecture)

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

SLOT_ID="${1:-}"
TASK_DESC="${2:-}"

if [[ -z "$SLOT_ID" || -z "$TASK_DESC" ]]; then
    echo "Usage: ccf start <slot_id> <task_description>"
    echo "Example: ccf start 1 'Fix auth bypass in src/auth.ts'"
    exit 1
fi

if [[ "$SLOT_ID" -lt 1 || "$SLOT_ID" -gt "$MAX_SLOTS" ]]; then
    error "Slot ID must be between 1 and $MAX_SLOTS"
    exit 1
fi

check_zellij
check_claude
check_git_repo

repo_id=$(register_repo)  # Auto-register if not already
repo_name=$(get_project_name)
SESSION_NAME=$(get_session_name "$SLOT_ID" "$repo_id")
TASK_ID=$(generate_task_id)

log "Starting task in slot $SLOT_ID for $repo_name: $TASK_DESC"

# Check if slot is already running
if zellij_session_exists "$SESSION_NAME" 2>/dev/null; then
    warn "Slot $SLOT_ID is currently running!"
    warn "Current task will be archived before starting new one."
    warn "To keep current task, use a different slot or 'ccf recycle $SLOT_ID' first."
    echo ""
    sleep 2
fi

# Archive old worktree
archive_worktree "$SLOT_ID" 2>/dev/null || true

# Create new worktree in global factory
log "Creating worktree for task $TASK_ID"
WORKTREE_PATH=$(create_worktree "$SLOT_ID" "$TASK_ID")

# Kill existing session
if zellij_session_exists "$SESSION_NAME"; then
    log "Stopping existing session"
    zellij delete-session "$SESSION_NAME" 2>/dev/null || true
fi

# Start zellij session in worktree directory
cd "$WORKTREE_PATH"

zellij --session "$SESSION_NAME" options \
    --default-shell "bash" \
    --simplified-ui true &

sleep 2

# Check if session is ready
if ! zellij_session_exists "$SESSION_NAME"; then
    error "Failed to start zellij session"
    exit 1
fi

# Start claude with task
log "Starting Claude Code..."

# Build prompt with first principles
FULL_PROMPT="Task: $TASK_DESC

Follow first principles:
- Go deeper: find root cause, not symptoms
- Map full lifecycle: consider all edge cases  
- Extend existing: don't duplicate code
- Every addition must be load-bearing
- Make illegal states unrepresentable
- One source of truth

Working directory: $WORKTREE_PATH
Original repo: $(get_project_root)
"

# Start claude
zellij --session "$SESSION_NAME" action write-chars "claude --dangerously-skip-permissions"
zellij --session "$SESSION_NAME" action write-chars "
"
sleep 1

# Send task
zellij --session "$SESSION_NAME" action write-chars "$FULL_PROMPT"
zellij --session "$SESSION_NAME" action write-chars "
"

# Update status
update_slot_status "$SLOT_ID" "running" "$TASK_DESC"

success "Slot $SLOT_ID started for $repo_name"
worktree_branch=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
worktree_commit=$(git -C "$WORKTREE_PATH" log --oneline -1 2>/dev/null | awk '{print $1}' || echo "unknown")
log "Branch: $worktree_branch"
log "Base commit: $worktree_commit"
log "Worktree: $WORKTREE_PATH"
log ""
log "Commands:"
log "  ccf attach $SLOT_ID           - Interactive attach"
log "  ccf cmd $SLOT_ID '/simplify'  - Send slash command"
log "  ccf recycle $SLOT_ID          - Finish task (deletes branch)"
log ""
log "After commit: push origin $worktree_branch → create PR → ccf recycle $SLOT_ID"
