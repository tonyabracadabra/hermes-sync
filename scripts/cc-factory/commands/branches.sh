#!/bin/bash
# List all CC Factory branches across registered repos

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

MODE="${1:-all}"

check_git_repo 2>/dev/null || { error "Not in a git repository"; exit 1; }

repo_root=$(get_project_root)
repo_name=$(get_project_name)

if [[ "$MODE" == "all" ]]; then
    echo ""
    echo "CC Factory branches for $repo_name:"
    echo ""
    
    # List all cc/* branches with last commit info
    git -C "$repo_root" branch --list 'cc/*' --format '%(refname:short)|%(committerdate:short)|%(subject)' | while IFS='|' read -r branch date subject; do
        if [[ -n "$branch" ]]; then
            # Check if this branch has an active worktree
            worktree_info=$(git -C "$repo_root" worktree list --porcelain | grep -A1 "branch refs/heads/$branch" | head -1 || echo "")
            worktree_path=""
            slot_status=""
            
            if [[ -n "$worktree_info" ]]; then
                worktree_path=$(echo "$worktree_info" | awk '{print $2}')
                # Try to find slot from path
                slot_id=$(basename "$worktree_path" | sed 's/slot-//')
                if [[ -n "$slot_id" && "$slot_id" =~ ^[0-9]+$ ]]; then
                    repo_id=$(get_repo_id "$repo_root")
                    session_name=$(get_session_name "$slot_id" "$repo_id")
                    if zellij_session_exists "$session_name" 2>/dev/null; then
                        slot_status=" [● slot $slot_id running]"
                    else
                        slot_status=" [○ slot $slot_id stopped]"
                    fi
                fi
            fi
            
            printf "  %-50s | %-10s | %-30s%s\n" "$branch" "$date" "${subject:0:30}" "$slot_status"
        fi
    done
    
    # If no branches found
    if ! git -C "$repo_root" branch --list 'cc/*' | grep -q 'cc/'; then
        echo "  No CC Factory branches found."
        echo "  Start a task with: ccf start 1 '<task description>'"
    fi
    echo ""
    
    # Also show merged branches (optionally prunable)
    main_branch=""
    if git -C "$repo_root" rev-parse --verify main &>/dev/null; then
        main_branch="main"
    elif git -C "$repo_root" rev-parse --verify master &>/dev/null; then
        main_branch="master"
    fi
    
    if [[ -n "$main_branch" ]]; then
        merged=$(git -C "$repo_root" branch --merged "$main_branch" --list 'cc/*' | wc -l)
        if [[ "$merged" -gt 0 ]]; then
            echo "Tip: $merged branch(es) already merged into $main_branch can be cleaned up:"
            git -C "$repo_root" branch --merged "$main_branch" --list 'cc/*' | sed 's/^/  /'
            echo ""
            echo "Clean up with: git branch -d cc/<branch>"
        fi
    fi
else
    error "Unknown mode: $MODE"
    echo "Usage: ccf branches [all]"
fi
