# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **BPMspace** global agents and skills library for Claude Code CLI. It contains reusable role definitions (agents), task playbooks (skills), operational guides (runbooks), commands, and collaboration templates. All custom items use the `my-{org}-` prefix convention (e.g., `my-bpm-`) and are versioned under `my/`.

## Architecture

### Directory Structure

```
bpm-claude-global-agent-skill-library/
├── my/                      # All my-bpm-prefixed custom items
│   ├── skills/              # Directories (my-bpm-<name>/SKILL.md)
│   ├── agents/              # Flat files (my-bpm-<name>.md)
│   ├── commands/            # Flat files (my-bpm-<name>.md)
│   └── runbooks/            # Flat files (my-bpm-<name>.md)
├── runbooks/                # Standard operational guides
├── templates/               # Issue and PR templates
├── my-bpm-library-pull      # Pull my-bpm-items from repo to local
├── my-bpm-library-push      # Push my-bpm-items from local to repo
├── bcgasl               # Main install/update command
├── install              # Installer script
├── sync                 # Sync script
└── lib.sh               # Shared library functions
```

### The `my-{org}-` Naming Convention

Custom items use the `my-{org}-{name}` pattern, where `{org}` identifies the organization/library:
- `ORG_PREFIX="bpm"` → all BPMspace items are named `my-bpm-{name}`
- This allows multiple organizations' libraries to coexist without conflicts
- Original/installed items (without `my-` prefix) keep their original name
- Two versions can coexist: original for reference, custom for use

### Agent Hierarchy

The **Orchestrator** (`my-bpm-orchestrator-planner`) coordinates all work:
- Discovers MCP server availability and publishes an **MCP Availability Handoff**
- Decomposes goals into tasks with acceptance criteria
- Assigns work to implementer agents

Implementer agents:
- **my-bpm-backend-bash-php** - Bash scripts and PHP (Flight MVC)
- **my-bpm-workflow-n8n-api** - n8n workflows and REST APIs
- **my-bpm-data-mariadb-redis** - MariaDB migrations and Redis keyspace
- **my-bpm-security-reviewer** - AppSec reviews, TLS/HTTP headers
- **my-bpm-qa-tester** - Test harness development and execution

### Key Patterns

- Never probe MCP servers independently; rely on Orchestrator's handoff
- Never hardcode secrets; use `.env` files
- Scripts must be idempotent
- Handoff protocols include required context for downstream agents

## Installation

```bash
# Install bcgasl + my-bpm-library tools
curl -fsSL .../install | bash -s -- --global --with-my-bpm-library

# Then use
bcgasl                    # Install/update agents & skills
my-bpm-library-pull       # Pull my-bpm-items from repo
my-bpm-library-push       # Push my-bpm-items to repo
```

## my-bpm-library Workflow

```bash
# Pull latest from repo
my-bpm-library-pull

# After creating/modifying items locally
my-bpm-library-push

# Preview without changes
my-bpm-library-pull --dry-run
my-bpm-library-push --dry-run
```

## Technology Stack

- **Bash** - Automation scripts with strict mode (`set -euo pipefail`)
- **PHP/Flight** - MVC backend framework
- **MariaDB** - Database with forward-only migrations
- **Redis** - Caching with namespaced keys and TTL policies
- **n8n** - Workflow automation
- **php-crud-api** - REST API generation
