#!/bin/bash
# Hermes Sync Installation Script

set -e

REPO_URL="https://github.com/tonyabracadabra/hermes-sync"
INSTALL_DIR="${HOME}/.hermes-sync"
HERMES_DIR="${HOME}/.hermes"

echo "🚀 Installing Hermes Sync..."

# Check if already installed
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Hermes Sync already exists at $INSTALL_DIR"
    echo "Updating..."
    cd "$INSTALL_DIR"
    git pull origin main || true
else
    # Clone repository
    echo "Cloning from $REPO_URL..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Create link in .hermes
if [[ -d "$HERMES_DIR" ]]; then
    echo "Linking to Hermes..."
    ln -sf "$INSTALL_DIR" "$HERMES_DIR/sync"
else
    echo "Creating Hermes directory..."
    mkdir -p "$HERMES_DIR"
    ln -sf "$INSTALL_DIR" "$HERMES_DIR/sync"
fi

# Add to PATH if not present
SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
    if ! grep -q "hermes-sync/scripts" "$SHELL_RC" 2>/dev/null; then
        echo "Adding to PATH in $SHELL_RC..."
        echo 'export PATH="$HOME/.hermes/sync/scripts/cc-factory/bin:$PATH"' >> "$SHELL_RC"
        echo "✅ Please restart your shell or run: source $SHELL_RC"
    fi
fi

# Setup git hooks for auto-sync
echo "Setting up auto-sync hooks..."
mkdir -p "$HERMES_DIR/hooks"
cat > "$HERMES_DIR/hooks/post-memory-update" << 'HOOK'
#!/bin/bash
# Auto-sync after memory update

SYNC_DIR="$HOME/.hermes-sync"
cd "$SYNC_DIR" || exit 1

# Check if there are changes
if ! git diff --quiet memories/ 2>/dev/null; then
    echo "[🔄 Hermes Sync] Auto-committing memory changes..."
    git add memories/
    git commit -m "Auto: Memory update $(date '+%Y-%m-%d %H:%M')" || true
    
    # Check for secrets before push
    if git diff HEAD~1 HEAD | grep -Ei "(api_key|apikey|password|token|secret)" | grep -v "\*\*\*"; then
        echo "[⚠️  Hermes Sync] Potential secret detected! Aborting push."
        git reset HEAD~1
        exit 1
    fi
    
    git push origin main || echo "[⚠️  Hermes Sync] Push failed, will retry later"
fi
HOOK
chmod +x "$HERMES_DIR/hooks/post-memory-update"

echo ""
echo "✅ Hermes Sync installed!"
echo ""
echo "Next steps:"
echo "1. Configure your GitHub credentials for sync"
echo "2. Run: ccf status (to test)"
echo "3. Edit memories/ to add your knowledge"
echo ""
echo "Directory: $INSTALL_DIR"
echo "Linked to: $HERMES_DIR/sync"
