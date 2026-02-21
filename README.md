# BPMspace Claude Global Agents & Skills Library

This repository contains a collection of **agents**, **skills**, **runbooks** and **templates** designed for use with Claude Code CLI. These resources are installed globally on your development machine and reused across multiple projects.

## Contents

- `my/` – all custom `my-bpm-`prefixed items (skills, agents, commands, runbooks), versioned and synced across machines
- `runbooks/` – detailed operational guides for recurring processes
- `templates/` – issue and pull-request templates

### my/ Directory

All custom items follow the `my-bpm-` naming convention and live under `my/`:

| Type | Path | Format |
|------|------|--------|
| Skills | `my/skills/my-bpm-<name>/` | Directory with `SKILL.md` |
| Agents | `my/agents/my-bpm-<name>.md` | Flat .md file |
| Commands | `my/commands/my-bpm-<name>.md` | Flat .md file |
| Runbooks | `my/runbooks/my-bpm-<name>.md` | Flat .md file |

## Quick Start (neue Maschine)

Komplettes Setup in 3 Schritten:

```bash
# 1. Repo klonen
git clone git@github.com:BPMspaceUG/bpm-claude-global-agent-skill-library.git ~/bpm-claude-global-agent-skill-library

# 2. CLI-Tools installieren (bcgasl + my-bpm-library-pull + my-bpm-library-push)
cd ~/bpm-claude-global-agent-skill-library
./install --global --with-my-bpm-library

# 3. Alle my-bpm-Items nach ~/.claude/ installieren
my-bpm-library-pull
```

Danach stehen alle Skills, Agents, Commands und Runbooks in Claude Code zur Verfügung.

### Ohne Repo-Klon (curl|bash)

Nur `bcgasl` + my-bpm-library-Tools installieren (Repo wird beim ersten `my-bpm-library-pull` automatisch geklont):

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --global --with-my-bpm-library
my-bpm-library-pull
```

### Nur Standard-Skills (ohne my-bpm-library)

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash
```

With n8n skills:
```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/sync | bash -s -- --n8n
```

## Updates

### Repo bereits geklont

```bash
cd ~/bpm-claude-global-agent-skill-library && git pull
my-bpm-library-pull              # Aktualisiert alle my-bpm-Items lokal
```

### Oder via bcgasl

```bash
bcgasl                           # Standard-Items aktualisieren
bcgasl --n8n                     # Mit n8n-Skills
bcgasl --dry-run                 # Vorschau ohne Änderungen
```

## my-library: Push/Pull Sync

Synchronise custom `my-bpm-` items between machines via this Git repository.

### Pull (repo → local)

```bash
my-bpm-library-pull                  # Pull all my-bpm-items
my-bpm-library-pull --dry-run        # Preview what would change
my-bpm-library-pull --force          # Overwrite conflicts (repo wins)
my-bpm-library-pull --only-skills    # Pull only skills
my-bpm-library-pull --only-agents    # Pull only agents
my-bpm-library-pull --only-commands  # Pull only commands
my-bpm-library-pull --only-runbooks  # Pull only runbooks
my-bpm-library-pull --verbose        # Detailed output
```

### Push (local → repo)

```bash
my-bpm-library-push                          # Push all my-bpm-items
my-bpm-library-push --dry-run                # Preview what would change
my-bpm-library-push --force                  # Overwrite conflicts (local wins)
my-bpm-library-push --message "custom msg"   # Custom commit message
my-bpm-library-push --only-skills            # Push only skills
my-bpm-library-push --verbose                # Detailed output
```

### Conflict Detection

Both scripts track a SHA256 baseline per item in `~/.claude/.my-bpm-library-sync`. When an item has changed on **both** sides (locally and in the repo) since the last sync, it is flagged as a conflict and **skipped**:

```
  X skills/my-bpm-foo (CONFLICT: changed locally AND in repo)

CONFLICTS: 1 item(s) changed on both sides.
  Review manually, then re-run. Or use --force to let repo win.
```

| Scenario | Pull | Push |
|----------|------|------|
| Only repo changed | Updates local | — |
| Only local changed | — | Updates repo |
| Both changed | **CONFLICT** (skipped) | **CONFLICT** (skipped) |
| Both changed + `--force` | Repo wins | Local wins |
| No baseline (first sync) | Updates local | Updates repo |

### Typischer Workflow

```bash
# Auf Maschine A: neues Item erstellen und pushen
# (z.B. neuen Skill in ~/.claude/skills/my-bpm-foo/ anlegen)
my-bpm-library-push

# Auf Maschine B: Items synchronisieren
my-bpm-library-pull
```

## Usage in Prompts

Reference these definitions in your prompts to Claude Code CLI:

- *"Use the Bash secure script standard to implement the installer."*
- *"As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff."*

## External Skill Packs

The n8n skill pack is maintained in a <a href="https://github.com/czlonkowski/n8n-skills" target="_blank">separate repository</a>. Use `bcgasl --n8n` to install it.

## License

This library is provided under the MIT License. See the `LICENSE` file for details.
