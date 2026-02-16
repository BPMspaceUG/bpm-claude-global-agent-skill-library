# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **BPMspace** global agents and skills library for Claude Code CLI. It contains reusable role definitions (agents), task playbooks (skills), operational guides (runbooks), commands, and collaboration templates. All custom items use the `my-` prefix and are versioned under `my/`.

## Architecture

### Directory Structure

```
bpm-claude-global-agent-skill-library/
├── my/                  # All my-prefixed custom items
│   ├── skills/          # Directories (my-<name>/SKILL.md)
│   ├── agents/          # Flat files (my-<name>.md)
│   ├── commands/        # Flat files (my-<name>.md)
│   └── runbooks/        # Flat files (my-<name>.md)
├── runbooks/            # Standard operational guides
├── templates/           # Issue and PR templates
├── my-library-pull      # Pull my-items from repo to local
├── my-library-push      # Push my-items from local to repo
├── bcgasl               # Main install/update command
├── install              # Installer script
├── sync                 # Sync script
└── lib.sh               # Shared library functions
```

### The `my-` Convention

All custom/user-created items use the `my-` prefix:
- `my-` = user-created or user-modified
- Original/installed items keep their original name
- Two versions can coexist: original for reference, custom for use

### Agent Hierarchy

The **Orchestrator** (`my-orchestrator-planner`) coordinates all work:
- Discovers MCP server availability and publishes an **MCP Availability Handoff**
- Decomposes goals into tasks with acceptance criteria
- Assigns work to implementer agents

Implementer agents:
- **my-backend-bash-php** - Bash scripts and PHP (Flight MVC)
- **my-workflow-n8n-api** - n8n workflows and REST APIs
- **my-data-mariadb-redis** - MariaDB migrations and Redis keyspace
- **my-security-reviewer** - AppSec reviews, TLS/HTTP headers
- **my-qa-tester** - Test harness development and execution

### Key Patterns

- Never probe MCP servers independently; rely on Orchestrator's handoff
- Never hardcode secrets; use `.env` files
- Scripts must be idempotent
- Handoff protocols include required context for downstream agents

## Installation

```bash
# Install bcgasl + my-library tools
curl -fsSL .../install | bash -s -- --global --with-my-library

# Then use
bcgasl                # Install/update agents & skills
my-library-pull       # Pull my-items from repo
my-library-push       # Push my-items to repo
```

## my-library Workflow

```bash
# Pull latest from repo
my-library-pull

# After creating/modifying items locally
my-library-push

# Preview without changes
my-library-pull --dry-run
my-library-push --dry-run
```

## Technology Stack

- **Bash** - Automation scripts with strict mode (`set -euo pipefail`)
- **PHP/Flight** - MVC backend framework
- **MariaDB** - Database with forward-only migrations
- **Redis** - Caching with namespaced keys and TTL policies
- **n8n** - Workflow automation
- **php-crud-api** - REST API generation
