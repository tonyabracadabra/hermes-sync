#!/bin/bash
# Show CC Factory status - Global view or specific repo

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

# Check if we want global view or current repo
MODE="${1:-current}"  # 'current', 'all', or specific repo_name

if [[ "$MODE" == "all" ]]; then
    # Global view - all repos
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║           CC Factory - Global Status (All Repositories)               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    ensure_factory_dirs
    
    found_any=false
    
    for repo_dir in "${FACTORY_ROOT}/repos"/*; do
        if [[ ! -d "$repo_dir" || ! -f "${repo_dir}/.repo_info.json" ]]; then
            continue
        fi
        
        found_any=true
        repo_id=$(basename "$repo_dir")
        repo_info=$(cat "${repo_dir}/.repo_info.json" 2>/dev/null)
        repo_name=$(echo "$repo_info" | grep -o '"repo_name": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        repo_path=$(echo "$repo_info" | grep -o '"repo_path": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        
        echo "┌─ $repo_name ($repo_id)"
        echo "│   Path: $repo_path"
        echo "│"
        
        for i in $(seq 1 "$MAX_SLOTS"); do
            status_file="${repo_dir}/status/slot-${i}.json"
            if [[ -f "$status_file" ]]; then
                STATUS_INFO=$(cat "$status_file")
                STATUS=$(echo "$STATUS_INFO" | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "idle")
                TASK=$(echo "$STATUS_INFO" | grep -o '"task": "[^"]*"' | cut -d'"' -f4 | head -c 40 || echo "")
                
                SESSION_NAME=$(get_session_name "$i" "$repo_id")
                if zellij_session_exists "$SESSION_NAME" 2>/dev/null; then
                    RUNNING_ICON="●"
                else
                    RUNNING_ICON="○"
                    [[ "$STATUS" == "running" ]] && STATUS="stopped"
                fi
                
                printf "│   %s slot %d: %-9s │ %-40s\n" "$RUNNING_ICON" "$i" "$STATUS" "${TASK:-<idle>}"
            fi
        done
        echo "└──────────────────────────────────────────────────────────────────────"
        echo ""
    done
    
    if [[ "$found_any" == "false" ]]; then
        echo "No repositories registered yet."
        echo "Run 'ccf start <slot> <task>' in any git repository to begin."
    fi
    
    echo "Legend: ● Running  ○ Idle/Stopped"
    echo "Commands: ccf start <n> <desc> | ccf attach <n> | ccf cmd <n> <cmd>"
    echo "          ccf status all         - View all repos"
    echo "          ccf status <repo_name> - View specific repo"
    
elif [[ "$MODE" == "current" ]]; then
    # Current repo view (original behavior, adapted for global)
    check_git_repo 2>/dev/null || { error "Not a git repository"; exit 1; }
    
    repo_id=$(get_repo_id)
    repo_name=$(get_project_name)
    factory_dir=$(get_repo_factory_dir "$repo_id")
    
    # Auto-register if not exists
    if [[ ! -f "${factory_dir}/.repo_path" ]]; then
        register_repo > /dev/null
    fi
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  CC Factory: $repo_name"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "Slot │ Status    │ Task"
    echo "─────┼───────────┼─────────────────────────────────────────────────"
    
    for i in $(seq 1 "$MAX_SLOTS"); do
        STATUS_INFO=$(get_slot_status "$i" "$repo_id")
        STATUS=$(echo "$STATUS_INFO" | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "idle")
        TASK=$(echo "$STATUS_INFO" | grep -o '"task": "[^"]*"' | cut -d'"' -f4 | head -c 45 || echo "")
        
        SESSION_NAME=$(get_session_name "$i" "$repo_id")
        if zellij_session_exists "$SESSION_NAME" 2>/dev/null; then
            RUNNING_ICON="●"
        else
            RUNNING_ICON="○"
            [[ "$STATUS" == "running" ]] && STATUS="stopped"
        fi
        
        printf "%s %d   │ %-9s │ %-45s\n" "$RUNNING_ICON" "$i" "$STATUS" "${TASK:-<idle>}"
    done
    
    echo ""
    echo "Legend: ● Running  ○ Idle/Stopped"
    echo ""
    echo "Commands: ccf start <n> <desc> | ccf attach <n> | ccf cmd <n> <cmd>"
else
    # View specific repo by name or ID
    target_repo="$MODE"
    found=false
    
    for repo_dir in "${FACTORY_ROOT}/repos"/*; do
        if [[ ! -d "$repo_dir" ]]; then
            continue
        fi
        
        repo_id=$(basename "$repo_dir")
        if [[ "$repo_id" == "$target_repo" || "$repo_id" == "${target_repo}_"* ]]; then
            found=true
            repo_info=$(cat "${repo_dir}/.repo_info.json" 2>/dev/null)
            repo_name=$(echo "$repo_info" | grep -o '"repo_name": "[^"]*"' | cut -d'"' -f4 || echo "unknown")
            
            echo ""
            echo "╔══════════════════════════════════════════════════════════════════╗"
            echo "║  CC Factory: $repo_name"
            echo "╚══════════════════════════════════════════════════════════════════╝"
            echo ""
            
            echo "Slot │ Status    │ Task"
            echo "─────┼───────────┼─────────────────────────────────────────────────"
            
            for i in $(seq 1 "$MAX_SLOTS"); do
                STATUS_INFO=$(get_slot_status "$i" "$repo_id")
                STATUS=$(echo "$STATUS_INFO" | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "idle")
                TASK=$(echo "$STATUS_INFO" | grep -o '"task": "[^"]*"' | cut -d'"' -f4 | head -c 45 || echo "")
                
                SESSION_NAME=$(get_session_name "$i" "$repo_id")
                if zellij_session_exists "$SESSION_NAME" 2>/dev/null; then
                    RUNNING_ICON="●"
                else
                    RUNNING_ICON="○"
                    [[ "$STATUS" == "running" ]] && STATUS="stopped"
                fi
                
                printf "%s %d   │ %-9s │ %-45s\n" "$RUNNING_ICON" "$i" "$STATUS" "${TASK:-<idle>}"
            done
            
            break
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        error "Repository '$target_repo' not found."
        echo "Run 'ccf status all' to see all registered repositories."
        exit 1
    fi
fi
