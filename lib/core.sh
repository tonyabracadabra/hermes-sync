#!/bin/bash
# Hermes Sync Core Functions - Global Factory Architecture

set -euo pipefail

# Configuration
HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
MAX_SLOTS="${MAX_SLOTS:-5}"
FACTORY_NAME="${FACTORY_NAME:-cc-factory}"
FACTORY_ROOT="${HOME}/.cc-factory"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[${FACTORY_NAME}]${NC} $1"; }
success() { echo -e "${GREEN}[${FACTORY_NAME}]${NC} $1"; }
warn() { echo -e "${YELLOW}[${FACTORY_NAME}]${NC} $1"; }
error() { echo -e "${RED}[${FACTORY_NAME}]${NC} $1"; }

# Get global factory root
get_factory_root() {
    echo "$FACTORY_ROOT"
}

# Ensure factory directory structure exists
ensure_factory_dirs() {
    mkdir -p "${FACTORY_ROOT}/repos"
}

# Get repo ID from path (hash-based to avoid special chars)
get_repo_id() {
    local repo_path="${1:-$(get_project_root)}"
    # Use path hash + last dir name for uniqueness and readability
    local path_hash=$(echo "$repo_path" | sha256sum | cut -c1-8)
    local dir_name=$(basename "$repo_path")
    echo "${dir_name}_${path_hash}"
}

# Get repo path from repo_id (reverse lookup via stored metadata)
get_repo_path() {
    local repo_id=$1
    local meta_file="${FACTORY_ROOT}/repos/${repo_id}/.repo_path"
    if [[ -f "$meta_file" ]]; then
        cat "$meta_file"
    else
        echo ""
    fi
}

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

# Get repo base directory in factory
get_repo_factory_dir() {
    local repo_id=$1
    echo "${FACTORY_ROOT}/repos/${repo_id}"
}

# Register repo in factory (stores metadata)
register_repo() {
    local repo_root=$(get_project_root)
    local repo_id=$(get_repo_id "$repo_root")
    local factory_dir=$(get_repo_factory_dir "$repo_id")
    
    ensure_factory_dirs
    mkdir -p "$factory_dir"/{worktrees,status,logs,archive}
    
    # Store repo path for reverse lookup
    echo "$repo_root" > "${factory_dir}/.repo_path"
    
    # Store repo metadata
    cat > "${factory_dir}/.repo_info.json" << EOF
{
    "repo_id": "${repo_id}",
    "repo_path": "${repo_root}",
    "repo_name": "$(get_project_name)",
    "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "$repo_id"
}

# Create worktree for slot in global factory
# Creates a fresh worktree based on origin/main (or origin/master)
create_worktree() {
    local slot_id=$1
    local task_id=$2
    local repo_root=$(get_project_root)
    local repo_id=$(get_repo_id "$repo_root")
    local factory_dir=$(get_repo_factory_dir "$repo_id")
    local worktree_path="${factory_dir}/worktrees/slot-${slot_id}"
    local branch_name="cc/${task_id}"
    
    # Ensure repo is registered
    if [[ ! -f "${factory_dir}/.repo_path" ]]; then
        register_repo > /dev/null
    fi
    
    # Archive old if exists
    if [[ -d "$worktree_path" ]]; then
        local archive_dir="${factory_dir}/archive"
        mkdir -p "$archive_dir"
        git -C "$repo_root" worktree remove "$worktree_path" 2>/dev/null || true
        mv "$worktree_path" "${archive_dir}/slot-${slot_id}-$(date +%s)" 2>/dev/null || true
    fi
    
    # Clean up stale worktree registrations and old branches
    git -C "$repo_root" worktree prune 2>/dev/null || true
    
    # Delete old branch if exists (clean start)
    git -C "$repo_root" branch -D "$branch_name" 2>/dev/null || true
    
    # Fetch latest from origin to ensure we're based on newest main
    log "Fetching latest from origin..."
    git -C "$repo_root" fetch origin 2>/dev/null || warn "Failed to fetch from origin, using local branches"
    
    # Determine base branch (main or master)
    local base_branch=""
    if git -C "$repo_root" rev-parse --verify origin/main &>/dev/null; then
        base_branch="origin/main"
    elif git -C "$repo_root" rev-parse --verify origin/master &>/dev/null; then
        base_branch="origin/master"
    elif git -C "$repo_root" rev-parse --verify main &>/dev/null; then
        base_branch="main"
    elif git -C "$repo_root" rev-parse --verify master &>/dev/null; then
        base_branch="master"
    else
        base_branch="HEAD"
        warn "No main/master branch found, using current HEAD"
    fi
    
    log "Creating worktree from base: $base_branch"
    
    # Create worktree with new branch based on origin/main
    # Use -B to force create/reset branch, ensuring clean state
    if ! git -C "$repo_root" worktree add -b "$branch_name" "$worktree_path" "$base_branch" 2>/dev/null; then
        # Fallback: branch might exist locally, try to use it
        if ! git -C "$repo_root" worktree add "$worktree_path" "$branch_name" 2>/dev/null; then
            error "Failed to create worktree for slot $slot_id"
            error "Base branch: $base_branch"
            error "Worktree path: $worktree_path"
            exit 1
        fi
    fi
    
    # Verify worktree was created
    if [[ ! -d "$worktree_path/.git" ]]; then
        error "Worktree creation failed: $worktree_path"
        exit 1
    fi
    
    # Log the commit we're based on
    local base_commit=$(git -C "$worktree_path" rev-parse --short HEAD)
    log "Worktree created at commit: $base_commit (from $base_branch)"
    
    echo "$worktree_path"
}

# Archive worktree
# Optionally deletes the associated branch (default: keep branch for PR)
archive_worktree() {
    local slot_id=$1
    local delete_branch="${2:-false}"
    local repo_root=$(get_project_root)
    local repo_id=$(get_repo_id "$repo_root")
    local factory_dir=$(get_repo_factory_dir "$repo_id")
    local worktree_path="${factory_dir}/worktrees/slot-${slot_id}"
    local archive_dir="${factory_dir}/archive"
    
    # Get branch name before removing worktree (if we need to delete it)
    local branch_name=""
    if [[ "$delete_branch" == "true" && -d "$worktree_path" ]]; then
        branch_name=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    fi
    
    if [[ -d "$worktree_path" ]]; then
        mkdir -p "$archive_dir"
        # Properly remove from git worktree list
        if ! git -C "$repo_root" worktree remove "$worktree_path" 2>/dev/null; then
            # Force remove if normal remove fails (uncommitted changes, etc)
            git -C "$repo_root" worktree remove --force "$worktree_path" 2>/dev/null || true
        fi
        # Move to archive even if git worktree remove failed
        mv "$worktree_path" "${archive_dir}/slot-${slot_id}-$(date +%s)" 2>/dev/null || true
    fi
    
    # Optionally delete branch (for recycle command - task is done)
    if [[ "$delete_branch" == "true" && -n "$branch_name" && "$branch_name" != HEAD ]]; then
        git -C "$repo_root" branch -D "$branch_name" 2>/dev/null || true
        log "Deleted branch: $branch_name"
    fi
    
    # Clean up stale worktree registrations
    git -C "$repo_root" worktree prune 2>/dev/null || true
}

# Get slot status file (global)
get_slot_status_file() {
    local slot_id=$1
    local repo_id="${2:-$(get_repo_id)}"
    local factory_dir=$(get_repo_factory_dir "$repo_id")
    echo "${factory_dir}/status/slot-${slot_id}.json"
}

# Update slot status (global)
update_slot_status() {
    local slot_id=$1
    local status=$2
    local task_desc="${3:-}"
    local repo_root=$(get_project_root)
    local repo_id=$(get_repo_id "$repo_root")
    local factory_dir=$(get_repo_factory_dir "$repo_id")
    local status_file=$(get_slot_status_file "$slot_id" "$repo_id")
    local worktree_path="${factory_dir}/worktrees/slot-${slot_id}"
    
    mkdir -p "$(dirname "$status_file")"
    
    cat > "$status_file" << EOF
{
    "slot_id": ${slot_id},
    "status": "${status}",
    "task": "${task_desc}",
    "repo_name": "$(get_project_name)",
    "repo_path": "${repo_root}",
    "repo_id": "${repo_id}",
    "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "worktree": "${worktree_path}"
}
EOF
}

# Get slot status (global)
get_slot_status() {
    local slot_id=$1
    local repo_id="${2:-$(get_repo_id)}"
    local status_file=$(get_slot_status_file "$slot_id" "$repo_id")
    
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

# Get session name (using repo_id for uniqueness across all repos)
get_session_name() {
    local slot_id=$1
    local repo_id="${2:-$(get_repo_id)}"
    echo "${FACTORY_NAME}-${repo_id}-${slot_id}"
}

# List all registered repos
list_registered_repos() {
    if [[ ! -d "${FACTORY_ROOT}/repos" ]]; then
        return
    fi
    
    for repo_dir in "${FACTORY_ROOT}/repos"/*; do
        if [[ -d "$repo_dir" && -f "${repo_dir}/.repo_info.json" ]]; then
            basename "$repo_dir"
        fi
    done
}

# Get all slots status for all repos or specific repo
get_all_slots_status() {
    local target_repo_id="${1:-}"
    
    if [[ ! -d "${FACTORY_ROOT}/repos" ]]; then
        return
    fi
    
    for repo_dir in "${FACTORY_ROOT}/repos"/*; do
        if [[ ! -d "$repo_dir" ]]; then
            continue
        fi
        
        local repo_id=$(basename "$repo_dir")
        
        # Filter if target specified
        if [[ -n "$target_repo_id" && "$repo_id" != "$target_repo_id" ]]; then
            continue
        fi
        
        local repo_info="${repo_dir}/.repo_info.json"
        local repo_name="unknown"
        if [[ -f "$repo_info" ]]; then
            repo_name=$(grep -o '"repo_name": "[^"]*"' "$repo_info" | cut -d'"' -f4 || echo "unknown")
        fi
        
        for i in $(seq 1 "$MAX_SLOTS"); do
            local status_file="${repo_dir}/status/slot-${i}.json"
            if [[ -f "$status_file" ]]; then
                echo "${repo_id}|${repo_name}|${i}|$(cat "$status_file")"
            fi
        done
    done
}
