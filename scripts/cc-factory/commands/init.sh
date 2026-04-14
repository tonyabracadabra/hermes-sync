#!/bin/bash
# Initialize/Register repo in CC Factory (Global Architecture)
# This is now optional - repos are auto-registered on first use

set -euo pipefail

HERMES_SYNC_HOME="${HERMES_SYNC_HOME:-$HOME/.hermes-sync}"
source "${HERMES_SYNC_HOME}/lib/core.sh"

check_git_repo

repo_root=$(get_project_root)
repo_id=$(get_repo_id "$repo_root")
factory_dir=$(get_repo_factory_dir "$repo_id")

log "Registering repository in CC Factory..."
log "  Repo: $(get_project_name)"
log "  Path: $repo_root"
log "  ID:   $repo_id"

# Register the repo
register_repo

success "Repository registered!"
echo ""
echo "Factory directory: $factory_dir"
echo ""
echo "Note: Manual init is optional. Repos are auto-registered on first 'ccf start'."
echo "Run 'ccf status' to check slots for this repository."
