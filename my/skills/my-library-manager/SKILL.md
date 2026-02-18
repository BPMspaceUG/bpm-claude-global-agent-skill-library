---
model: opus
name: my-library-manager
description: Central knowledge hub for the my- item convention, library management, and push/pull synchronisation. Use when the user asks about my-library, wants to sync items, discusses the my- naming convention, or needs guidance on creating/managing custom items across skills, agents, commands, and runbooks.
---

# Library Manager

Central knowledge hub for managing `my-` prefixed custom items across all artefact types. Coordinates push/pull synchronisation via the Git repository.

## The `my-` Convention

**All custom/user-created items use the `my-` prefix.** This applies to ALL artefact types:

| Type | Location | Format | Example |
|------|----------|--------|---------|
| Skills | `~/.claude/skills/my-<name>/` | Directory with `SKILL.md` | `my-flightphp-pro/SKILL.md` |
| Agents | `~/.claude/agents/my-<name>.md` | Flat .md file | `my-orchestrator-planner.md` |
| Commands | `~/.claude/commands/my-<name>.md` | Flat .md file | `my-refactor-repo.md` |
| Runbooks | `~/.claude/runbooks/my-<name>.md` | Flat .md file | `my-deployment.md` |

### Rules

- `my-` prefix = user-created or user-modified, **always**
- Original/installed items keep their original name — **never rename**
- Two versions can coexist: original for reference, custom for use
- Rollback: delete `my-` version, original still works

## Repository Structure

All `my-` items are versioned in the Git repository under `my/`:

```
bpm-claude-global-agent-skill-library/
├── my/
│   ├── skills/          # Directories (my-<name>/SKILL.md)
│   ├── agents/          # Flat files (my-<name>.md)
│   ├── commands/        # Flat files (my-<name>.md)
│   └── runbooks/        # Flat files (my-<name>.md)
├── my-library-pull      # Pull script
├── my-library-push      # Push script
└── ...
```

## CLI Commands

### `my-library-pull` — Download from repo to local

```bash
my-library-pull                  # Pull all my-items
my-library-pull --dry-run        # Preview changes
my-library-pull --only-skills    # Pull only skills
my-library-pull --verbose        # Detailed output
```

**Use when:**
- Setting up a new machine
- Getting updates from another machine
- After someone else pushed changes

### `my-library-push` — Upload from local to repo

```bash
my-library-push                          # Push all my-items
my-library-push --dry-run                # Preview changes
my-library-push --message "custom msg"   # Custom commit message
my-library-push --only-skills            # Push only skills
```

**Use when:**
- After creating a new custom item
- After modifying an existing custom item
- Before switching to another machine

Push includes: sync → add → commit → push in one step.

## Decision Flow

```
User wants to create something new?
├── Is it a skill?
│   ├── Does my-<name> exist? → Use my-skill-optimizer
│   └── New? → Use my-skill-creator (creates with my- prefix)
├── Is it an agent/command/runbook?
│   └── Create as my-<name>.md in appropriate directory
└── After creation:
    └── Run my-library-push to version it
```

## Creating New Items

### New Skill
1. Use `my-skill-creator` or `my-skill-optimizer`
2. Creates `~/.claude/skills/my-<name>/SKILL.md`
3. `my-library-push` to sync to repo

### New Agent
1. Create `~/.claude/agents/my-<name>.md`
2. Follow agent format: Purpose, Responsibilities, Guardrails, Handoff Protocol
3. `my-library-push` to sync to repo

### New Command
1. Create `~/.claude/commands/my-<name>.md`
2. Follow command format with frontmatter (allowed-tools, model, description)
3. `my-library-push` to sync to repo

### New Runbook
1. Create `~/.claude/runbooks/my-<name>.md`
2. Follow runbook format: steps, prerequisites, verification
3. `my-library-push` to sync to repo

## Integration with Other Skills

- **my-skill-creator**: Creates new skills → always with `my-` prefix → push when done
- **my-skill-optimizer**: Optimizes existing skills → fork to `my-` version → push when done
- **my-flightphp-pro**: Example of optimized skill derived from original

## Conflict Handling

- `my-library-pull` uses `git pull --ff-only` — fails safely on conflicts
- `my-library-push` pulls first, then pushes — detects conflicts early
- Deleted items: shown as warnings, **never auto-deleted** (safety)
- Resolution: manual `cd ~/bpm-claude-global-agent-skill-library && git status`
