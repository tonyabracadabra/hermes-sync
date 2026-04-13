#!/bin/bash
# Show CC Factory status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/core.sh"

check_git_repo 2>/dev/null || { error "Not a git repository"; exit 1; }

PROJECT=$(get_project_name)

echo ""
echo "╔═══════════════════════════════════════════════════════════"
echo "║  CC Factory: $PROJECT"
echo "╚═══════════════════════════════════════════════════════════"
echo ""

echo "Slot │ Status    │ Task"
echo "─────┼───────────┼─────────────────────────────────────────"

for i in $(seq 1 "$MAX_SLOTS"); do
    STATUS_INFO=$(get_slot_status "$i")
    STATUS=$(echo "$STATUS_INFO" | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "idle")
    TASK=$(echo "$STATUS_INFO" | grep -o '"task": "[^"]*"' | cut -d'"' -f4 | head -c 50 || echo "")
    
    # Check if zellij session is actually running
    SESSION_NAME=$(get_session_name "$i")
    if zellij_session_exists "$SESSION_NAME" 2>/dev/null; then
        RUNNING_ICON="●"
    else
        RUNNING_ICON="○"
        [[ "$STATUS" == "running" ]] && STATUS="stopped"
    fi
    
    printf "%s %d   │ %-9s │ %-40s\n" "$RUNNING_ICON" "$i" "$STATUS" "${TASK:-<idle>}"
done

echo ""
echo "Legend: ● Running  ○ Idle/Stopped"
echo ""
echo "Commands: ccf start <n> <desc> | ccf attach <n> | ccf cmd <n> <cmd>"
