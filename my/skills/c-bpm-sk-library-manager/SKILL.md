---
model: opus
name: c-bpm-sk-library-manager
description: Central knowledge hub for the c-bpm- item convention, library management, and push/pull synchronisation. Use when the user asks about the library, wants to sync items, discusses the c-bpm- naming convention, or needs guidance on creating/managing custom items across skills, agents, commands, and runbooks.
---

# Library Manager

Central knowledge hub for managing `c-bpm-` prefixed custom items across all artefact types. Coordinates push/pull synchronisation via the Git repository.

## The `c-bpm-` Convention

**All custom/user-created items use the `c-bpm-` prefix with a type infix.** This applies to ALL artefact types:

| Type | Prefix | Location | Format | Example |
|------|--------|----------|--------|---------|
| Skills | `c-bpm-sk-` | `~/.claude/skills/c-bpm-sk-<name>/` | Directory with `SKILL.md` | `c-bpm-sk-flightphp-pro/SKILL.md` |
| Agents | `c-bpm-ag-` | `~/.claude/agents/c-bpm-ag-<name>.md` | Flat .md file | `c-bpm-ag-orchestrator-planner.md` |
| Commands | `c-bpm-cm-` | `~/.claude/commands/c-bpm-cm-<name>.md` | Flat .md file | `c-bpm-cm-refactor-repo.md` |
| Runbooks | `c-bpm-rb-` | `~/.claude/runbooks/c-bpm-rb-<name>.md` | Flat .md file | `c-bpm-rb-deployment.md` |

### Rules

- `c-bpm-` prefix with type infix = user-created or user-modified, **always**
- Original/installed items keep their original name — **never rename**
- Two versions can coexist: original for reference, custom for use
- Rollback: delete `c-bpm-` version, original still works

## Repository Structure

All `c-bpm-` items are versioned in the Git repository under `my/`:

```
bpm-claude-global-agent-skill-library/
├── my/
│   ├── skills/          # Directories (c-bpm-sk-<name>/SKILL.md)
│   ├── agents/          # Flat files (c-bpm-ag-<name>.md)
│   ├── commands/        # Flat files (c-bpm-cm-<name>.md)
│   └── runbooks/        # Flat files (c-bpm-rb-<name>.md)
├── c-bpm-cm-library-pull      # Pull script
├── c-bpm-cm-library-push      # Push script
└── ...
```

## CLI Commands

### `c-bpm-cm-library-pull` — Download from repo to local

```bash
c-bpm-cm-library-pull                  # Pull all items
c-bpm-cm-library-pull --dry-run        # Preview changes
c-bpm-cm-library-pull --only-skills    # Pull only skills
c-bpm-cm-library-pull --verbose        # Detailed output
```

**Use when:**
- Setting up a new machine
- Getting updates from another machine
- After someone else pushed changes

### `c-bpm-cm-library-push` — Upload from local to repo

```bash
c-bpm-cm-library-push                          # Push all items
c-bpm-cm-library-push --dry-run                # Preview changes
c-bpm-cm-library-push --message "custom msg"   # Custom commit message
c-bpm-cm-library-push --only-skills            # Push only skills
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
│   ├── Does c-bpm-sk-<name> exist? → Use c-bpm-sk-skill-optimizer
│   └── New? → Use c-bpm-sk-skill-creator (creates with c-bpm-sk- prefix)
├── Is it an agent/command/runbook?
│   └── Create as c-bpm-{type}-<name>.md in appropriate directory
└── After creation:
    └── Run c-bpm-cm-library-push to version it
```

## Creating New Items

### New Skill
1. Use `c-bpm-sk-skill-creator` or `c-bpm-sk-skill-optimizer`
2. Creates `~/.claude/skills/c-bpm-sk-<name>/SKILL.md`
3. `c-bpm-cm-library-push` to sync to repo

### New Agent
1. Create `~/.claude/agents/c-bpm-ag-<name>.md`
2. Follow agent format: Purpose, Responsibilities, Guardrails, Handoff Protocol
3. `c-bpm-cm-library-push` to sync to repo

### New Command
1. Create `~/.claude/commands/c-bpm-cm-<name>.md`
2. Follow command format with frontmatter (allowed-tools, model, description)
3. `c-bpm-cm-library-push` to sync to repo

### New Runbook
1. Create `~/.claude/runbooks/c-bpm-rb-<name>.md`
2. Follow runbook format: steps, prerequisites, verification
3. `c-bpm-cm-library-push` to sync to repo

## Integration with Other Skills

- **c-bpm-sk-skill-creator**: Creates new skills → always with `c-bpm-sk-` prefix → push when done
- **c-bpm-sk-skill-optimizer**: Optimizes existing skills → fork to `c-bpm-sk-` version → push when done
- **c-bpm-sk-flightphp-pro**: Example of optimized skill derived from original

## Conflict Handling

- `c-bpm-cm-library-pull` uses `git pull --ff-only` — fails safely on conflicts
- `c-bpm-cm-library-push` pulls first, then pushes — detects conflicts early
- Deleted items: shown as warnings, **never auto-deleted** (safety)
- Resolution: manual `cd ~/bpm-claude-global-agent-skill-library && git status`
