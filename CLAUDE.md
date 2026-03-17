# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **BPMspace** global agents and skills library for Claude Code CLI. It contains reusable role definitions (agents), task playbooks (skills), operational guides (runbooks), commands, and collaboration templates. All custom items use the `c-{org}-{type}-{name}` prefix convention (e.g., `c-bpm-sk-`, `c-bpm-ag-`) and are versioned under `my/`.

## Architecture

### Directory Structure

```
bpm-claude-global-agent-skill-library/
├── my/                      # All c-bpm-prefixed custom items
│   ├── skills/              # Directories (c-bpm-sk-<name>/SKILL.md)
│   ├── agents/              # Flat files (c-bpm-ag-<name>.md)
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
- `ITEM_PREFIX="c"`, `ORG_PREFIX="bpm"` with type codes: `sk` (skills), `ag` (agents), `cm` (commands), `rb` (runbooks)
- Example: `c-bpm-sk-bash-secure-script` (a skill), `c-bpm-ag-orchestrator-planner` (an agent)
- This allows multiple organizations' libraries to coexist without conflicts
- Original/installed items (without `c-` prefix) keep their original name
- Two versions can coexist: original for reference, custom for use

### Agent Hierarchy

The **Orchestrator** (`c-bpm-ag-orchestrator-planner`) coordinates all work:
- Discovers MCP server availability and publishes an **MCP Availability Handoff**
- Decomposes goals into tasks with acceptance criteria
- Assigns work to implementer agents

Implementer agents:
- **c-bpm-ag-backend-bash-php** - Bash scripts and PHP (Flight MVC)
- **c-bpm-ag-workflow-n8n-api** - n8n workflows and REST APIs
- **c-bpm-ag-data-mariadb-redis** - MariaDB migrations and Redis keyspace
- **c-bpm-ag-security-reviewer** - AppSec reviews, TLS/HTTP headers
- **c-bpm-ag-qa-tester** - Test harness development and execution

### Key Patterns

- Never probe MCP servers independently; rely on Orchestrator's handoff
- Never hardcode secrets; use `.env` files
- Scripts must be idempotent
- Handoff protocols include required context for downstream agents

## Installation

```bash
# Install bcgasl + c-bpm-library tools
curl -fsSL .../install | bash -s -- --global --with-c-bpm-library

# Then use
bcgasl                    # Install/update agents & skills
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
