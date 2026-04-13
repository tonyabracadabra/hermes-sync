#!/bin/bash
# Initialize CC Factory for current project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/core.sh"

log "Initializing CC Factory for $(get_project_name)..."

PROJECT_ROOT=$(get_project_root)

# Create directory structure
mkdir -p "${PROJECT_ROOT}/.cc-factory"/{worktrees,status,logs}
mkdir -p "${PROJECT_ROOT}/.cc-factory/worktrees/.archive"

# Create default config if not exists
if [[ ! -f "${PROJECT_ROOT}/.cc-factory.json" ]]; then
    cat > "${PROJECT_ROOT}/.cc-factory.json" << 'EOF'
{
  "name": "project",
  "max_slots": 5,
  "zellij_theme": "default",
  "test_command": "echo 'No test command configured'",
  "lint_command": "echo 'No lint command configured'",
  "auto_simplify": false,
  "auto_rebase": false
}
EOF
    log "Created .cc-factory.json"
fi

# Create .gitignore if not exists
if [[ ! -f "${PROJECT_ROOT}/.cc-factory/.gitignore" ]]; then
    cat > "${PROJECT_ROOT}/.cc-factory/.gitignore" << 'EOF'
# CC Factory local state
status/
logs/
worktrees/*/
!worktrees/.gitkeep
EOF
    log "Created .cc-factory/.gitignore"
fi

# Add to project's .gitignore if not present
if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
    if ! grep -q "\.cc-factory/" "${PROJECT_ROOT}/.gitignore"; then
        echo -e "\n# CC Factory\n.cc-factory/\n" >> "${PROJECT_ROOT}/.gitignore"
        log "Added .cc-factory/ to .gitignore"
    fi
fi

success "CC Factory initialized!"
log "Run 'ccf status' to check slots"
