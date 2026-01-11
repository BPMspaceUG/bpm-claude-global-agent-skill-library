# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a global agents and skills library for Claude Code CLI. It contains reusable role definitions (agents), task playbooks (skills), operational guides (runbooks), and collaboration templates. These resources are installed globally on development machines and referenced across multiple projects.

## Architecture

### Directory Structure

- `agents/` - Role definitions with responsibilities, inputs, outputs, and guardrails
- `skills/` - Standardized playbooks for common tasks with checklists and success criteria
- `runbooks/` - Detailed operational guides for recurring processes
- `templates/` - Issue and PR templates

### Agent Hierarchy

The **Orchestrator (A01)** coordinates all work:
- Discovers MCP server availability and publishes an **MCP Availability Handoff**
- Decomposes goals into tasks with acceptance criteria
- Assigns work to implementer agents

Implementer agents rely on the Orchestrator's plan and MCP handoff:
- **A02 Backend/Automation** - Bash scripts and PHP (Flight MVC)
- **A03 Workflow/Integration** - n8n workflows and REST APIs
- **A04 Data** - MariaDB migrations and Redis keyspace
- **A05 Security** - AppSec reviews, TLS/HTTP headers
- **A06 QA** - Test harness development and execution

### Key Patterns

All agents follow these conventions:
- Never probe MCP servers independently; rely on Orchestrator's handoff
- Never hardcode secrets; use `.env` files
- Scripts must be idempotent
- Handoff protocols include required context for downstream agents

## Installation

```bash
# Install the library
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash

# Install with optional n8n skills
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash -s -- --n8n
```

The sync script detects Claude config location (`~/.config/claude` or `~/.claude`) and copies the directories there.

## Usage Examples

Reference agents and skills in prompts:
- *"Use the Bash secure script standard to implement the installer."*
- *"As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff."*

## Technology Stack

- **Bash** - Automation scripts with strict mode (`set -euo pipefail`)
- **PHP/Flight** - MVC backend framework
- **MariaDB** - Database with forward-only migrations
- **Redis** - Caching with namespaced keys and TTL policies
- **n8n** - Workflow automation
- **php-crud-api** - REST API generation
