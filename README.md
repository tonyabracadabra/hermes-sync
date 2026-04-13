# Hermes Sync

Cross-machine memory and automation sync for Hermes AI assistant.

## Features

- **Git-synced memories**: Markdown-based knowledge that syncs across devices
- **CC Factory**: Multi-slot Claude Code automation with Zellij
- **Secrets-safe**: Automatic scrubbing of API keys and tokens
- **Auto-sync**: Push on change, pull on startup

## Quick Start

### Installation

```bash
# Clone to your hermes directory
git clone https://github.com/tonyabracadabra/hermes-sync.git ~/.hermes-sync

# Link into hermes
ln -sf ~/.hermes-sync ~/.hermes/sync

# Add to PATH
echo 'export PATH="$HOME/.hermes/sync/scripts/cc-factory/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Setup git sync (one-time)
./install.sh
```

### Daily Usage

```bash
# Start CC Factory task
ccf start 1 "Fix auth bypass in packages/worker/src/auth.ts"

# Check status
ccf status

# Sync memories
sync-now
```

## Directory Structure

```
~/.hermes-sync/
├── memories/           # Git-synced knowledge
│   ├── memory/         # Environment facts
│   └── user/           # User preferences
├── scripts/            # Automation scripts
│   └── cc-factory/     # Claude Code multi-agent
└── lib/                # Shared utilities
```

## Sync Behavior

| What | Synced? | Location |
|------|---------|----------|
| Memories | ✅ Yes | `memories/` |
| Scripts | ✅ Yes | `scripts/` |
| API Keys | ❌ No | `~/.hermes/.env` (local) |
| State | ❌ No | `~/.hermes/state.db` (local) |
| Sessions | ❌ No | `~/.hermes/sessions/` (local) |

## Security

Sensitive data is never synced:
- `.env` files are gitignored
- Config files are scrubbed before commit
- API keys are replaced with `***`

See [SECURITY.md](SECURITY.md) for details.

## License

MIT
