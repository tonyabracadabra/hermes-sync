#!/bin/bash
# Hermes Sync Core Functions

set -euo pipefail

# Configuration
HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
MAX_SLOTS="${MAX_SLOTS:-5}"
FACTORY_NAME="${FACTORY_NAME:-cc-factory}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[hermes-sync]${NC} $1"; }
success() { echo -e "${GREEN}[hermes-sync]${NC} $1"; }
warn() { echo -e "${YELLOW}[hermes-sync]${NC} $1"; }
error() { echo -e "${RED}[hermes-sync]${NC} $1"; }

# Check if running in a git repo
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not a git repository. Run 'git init' first."
        exit 1
    fi
}

# Get project root
get_project_root() {
    git rev-parse --show-toplevel
}

# Get current project name
get_project_name() {
    basename "$(get_project_root)"
}

# Check if zellij is installed
check_zellij() {
    if ! command -v zellij &> /dev/null; then
        error "zellij not found. Install with: cargo install zellij"
        exit 1
    fi
}

# Check if claude is installed
check_claude() {
    if ! command -v claude &> /dev/null; then
        error "claude not found. Install Claude Code first."
        exit 1
    fi
}

# Generate unique task ID
generate_task_id() {
    echo "$(date +%s)-$(openssl rand -hex 4)"
}

# Create worktree for slot
create_worktree() {
    local slot_id=$1
    local task_id=$2
    local project_root=$(get_project_root)
    local worktree_base="${project_root}/.cc-factory/worktrees"
    local worktree_path="${worktree_base}/slot-${slot_id}"
    
    mkdir -p "$worktree_base"
    
    # Archive old if exists
    if [[ -d "$worktree_path" ]]; then
        local archive_dir="${worktree_base}/.archive"
        mkdir -p "$archive_dir"
        mv "$worktree_path" "${archive_dir}/slot-${slot_id}-$(date +%s)"
    fi
    
    git worktree add "$worktree_path" -b "cc/${task_id}" 2>/dev/null || \
        git worktree add "$worktree_path" "cc/${task_id}" 2>/dev/null || \
        { error "Failed to create worktree"; exit 1; }
    
    echo "$worktree_path"
}

# Archive worktree
archive_worktree() {
    local slot_id=$1
    local project_root=$(get_project_root)
    local worktree_path="${project_root}/.cc-factory/worktrees/slot-${slot_id}"
    local archive_dir="${project_root}/.cc-factory/worktrees/.archive"
    
    if [[ -d "$worktree_path" ]]; then
        mkdir -p "$archive_dir"
        mv "$worktree_path" "${archive_dir}/slot-${slot_id}-$(date +%s)"
    fi
}

# Get slot status file
get_slot_status_file() {
    local slot_id=$1
    local project_root=$(get_project_root)
    echo "${project_root}/.cc-factory/status/slot-${slot_id}.json"
}

# Update slot status
update_slot_status() {
    local slot_id=$1
    local status=$2
    local task_desc="${3:-}"
    local project_root=$(get_project_root)
    local status_file=$(get_slot_status_file "$slot_id")
    local worktree_base="${project_root}/.cc-factory"
    
    mkdir -p "$(dirname "$status_file")"
    
    cat > "$status_file" << EOF
{
    "slot_id": ${slot_id},
    "status": "${status}",
    "task": "${task_desc}",
    "project": "$(get_project_name)",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "worktree": "${worktree_base}/worktrees/slot-${slot_id}"
}
EOF
}

# Get slot status
get_slot_status() {
    local slot_id=$1
    local status_file=$(get_slot_status_file "$slot_id")
    
    if [[ -f "$status_file" ]]; then
        cat "$status_file"
    else
        echo '{"status": "idle", "slot_id": '${slot_id}'}'
    fi
}

# Check if zellij session exists
zellij_session_exists() {
    local session_name=$1
    zellij list-sessions 2>/dev/null | grep -q "^${session_name}\s"
}

# Get project-specific session name
get_session_name() {
    local slot_id=$1
    local project=$(get_project_name)
    echo "${FACTORY_NAME}-${project}-${slot_id}"
}
