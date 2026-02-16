# BPMspace Claude Global Agents & Skills Library

This repository contains a collection of **agents**, **skills**, **runbooks** and **templates** designed for use with Claude Code CLI. These resources are installed globally on your development machine and reused across multiple projects.

## Contents

- `my/` – all custom `my-`prefixed items (skills, agents, commands, runbooks), versioned and synced across machines
- `runbooks/` – detailed operational guides for recurring processes
- `templates/` – issue and pull-request templates

### my/ Directory

All custom items follow the `my-` naming convention and live under `my/`:

| Type | Path | Format |
|------|------|--------|
| Skills | `my/skills/my-<name>/` | Directory with `SKILL.md` |
| Agents | `my/agents/my-<name>.md` | Flat .md file |
| Commands | `my/commands/my-<name>.md` | Flat .md file |
| Runbooks | `my/runbooks/my-<name>.md` | Flat .md file |

## Installation

### One-time usage

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash
```

With n8n skills:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash -s -- --n8n
```

### Install bcgasl command (for repeated use)

Interactive:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash
```

With my-library tools:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --global --with-my-library
```

### Usage

Install/update agents & skills:
```bash
bcgasl
```

With n8n skills:
```bash
bcgasl --n8n
```

Preview changes:
```bash
bcgasl --dry-run
```

## my-library: Push/Pull Sync

Synchronise custom `my-` items between machines via this Git repository.

### Pull (repo → local)

```bash
my-library-pull                  # Pull all my-items
my-library-pull --dry-run        # Preview what would change
my-library-pull --only-skills    # Pull only skills
```

### Push (local → repo)

```bash
my-library-push                          # Push all my-items
my-library-push --dry-run                # Preview what would change
my-library-push --message "custom msg"   # Custom commit message
my-library-push --only-skills            # Push only skills
```

### Workflow

1. Create or modify a custom item locally (`~/.claude/skills/my-foo/`, etc.)
2. `my-library-push` — syncs to repo (includes commit + push)
3. On another machine: `my-library-pull` — downloads and installs

## Usage in Prompts

Reference these definitions in your prompts to Claude Code CLI:

- *"Use the Bash secure script standard to implement the installer."*
- *"As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff."*

## External Skill Packs

The n8n skill pack is maintained in a <a href="https://github.com/czlonkowski/n8n-skills" target="_blank">separate repository</a>. Use `bcgasl --n8n` to install it.

## License

This library is provided under the MIT License. See the `LICENSE` file for details.
