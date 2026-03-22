# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **BPMspace** global skills library for Claude Code CLI. It contains task playbooks (skills), operational guides (runbooks), commands, and collaboration templates. All custom items use the `c-{org}-{type}-{name}` prefix convention (e.g., `c-bpm-sk-`, `c-bpm-cm-`) and are versioned under `my/`.

## Architecture

### Directory Structure

```
bpm-claude-global-agent-skill-library/
├── my/                      # All c-bpm-prefixed custom items
│   ├── skills/              # Directories (c-bpm-sk-<name>/SKILL.md)
│   ├── commands/            # Flat files (c-bpm-cm-<name>.md)
│   └── runbooks/            # Flat files (c-bpm-rb-<name>.md)
├── runbooks/                # Standard operational guides
├── templates/               # Issue and PR templates
├── c-bpm-cm-library-pull    # Pull c-bpm-items from repo to local
├── c-bpm-cm-library-push    # Push c-bpm-items from local to repo
├── bcgasl               # Main install/update command
├── install              # Installer script
├── sync                 # Sync script
└── lib.sh               # Shared library functions
```

### The `c-{org}-{type}-{name}` Naming Convention

Custom items use the `c-{org}-{type}-{name}` pattern:
- `ITEM_PREFIX="c"`, `ORG_PREFIX="bpm"` with type codes: `sk` (skills), `cm` (commands), `rb` (runbooks)
- Example: `c-bpm-sk-bash-secure-script` (a skill), `c-bpm-cm-refactor-repo` (a command)
- This allows multiple organizations' libraries to coexist without conflicts
- Original/installed items (without `c-` prefix) keep their original name
- Two versions can coexist: original for reference, custom for use

### Key Patterns

- Never hardcode secrets; use `.env` files
- Scripts must be idempotent
- Use skills for domain knowledge (see `c-bpm-sk-llm-selection` for orchestration and MCP discovery)

## Installation

```bash
# Install bcgasl + c-bpm-library tools
curl -fsSL .../install | bash -s -- --global --with-c-bpm-library

# Then use
bcgasl                    # Install/update skills
c-bpm-cm-library-pull     # Pull c-bpm-items from repo
c-bpm-cm-library-push     # Push c-bpm-items to repo
```

## c-bpm-library Workflow

```bash
# Pull latest from repo
c-bpm-cm-library-pull

# After creating/modifying items locally
c-bpm-cm-library-push

# Preview without changes
c-bpm-cm-library-pull --dry-run
c-bpm-cm-library-push --dry-run
```

## Technology Stack

- **Bash** - Automation scripts with strict mode (`set -euo pipefail`)
- **PHP/Flight** - MVC backend framework
- **MariaDB** - Database with forward-only migrations
- **Redis** - Caching with namespaced keys and TTL policies
- **n8n** - Workflow automation
- **php-crud-api** - REST API generation
