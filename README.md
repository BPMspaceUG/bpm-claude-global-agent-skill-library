# BPMspace Claude Global Agents & Skills Library

This repository contains a collection of **agents**, **skills**, **runbooks** and **templates** designed for use with Claude Code CLI. These resources are installed globally on your development machine and reused across multiple projects.

## Contents

- `my/` – all custom `c-bpm-`prefixed items (skills, agents, commands, runbooks), versioned and synced across machines
- `runbooks/` – detailed operational guides for recurring processes
- `templates/` – issue and pull-request templates

### my/ Directory

All custom items follow the `c-bpm-{type}-{name}` naming convention and live under `my/`:

| Type | Path | Format |
|------|------|--------|
| Skills | `my/skills/c-bpm-sk-<name>/` | Directory with `SKILL.md` |
| Agents | `my/agents/c-bpm-ag-<name>.md` | Flat .md file |
| Commands | `my/commands/c-bpm-cm-<name>.md` | Flat .md file |
| Runbooks | `my/runbooks/c-bpm-rb-<name>.md` | Flat .md file |

## Quick Start (neue Maschine)

Komplettes Setup in 3 Schritten:

```bash
# 1. Repo klonen
git clone git@github.com:BPMspaceUG/bpm-claude-global-agent-skill-library.git ~/bpm-claude-global-agent-skill-library

# 2. CLI-Tools installieren (bcgasl + c-bpm-cm-library-pull + c-bpm-cm-library-push)
cd ~/bpm-claude-global-agent-skill-library
./install --global --with-c-bpm-library

# 3. Alle c-bpm-Items nach ~/.claude/ installieren
c-bpm-cm-library-pull
```

Danach stehen alle Skills, Agents, Commands und Runbooks in Claude Code zur Verfügung.

### Ohne Repo-Klon (curl|bash)

Nur `bcgasl` + c-bpm-library-Tools installieren (Repo wird beim ersten `c-bpm-cm-library-pull` automatisch geklont):

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --global --with-c-bpm-library
c-bpm-cm-library-pull
```

### Nur Standard-Skills (ohne c-bpm-library)

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
c-bpm-cm-library-pull              # Aktualisiert alle c-bpm-Items lokal
```

### Oder via bcgasl

```bash
bcgasl                           # Standard-Items aktualisieren
bcgasl --n8n                     # Mit n8n-Skills
bcgasl --dry-run                 # Vorschau ohne Änderungen
```

## c-bpm-library: Push/Pull Sync

Synchronise custom `c-bpm-` items between machines via this Git repository.

### Pull (repo → local)

```bash
c-bpm-cm-library-pull                  # Pull all c-bpm-items
c-bpm-cm-library-pull --dry-run        # Preview what would change
c-bpm-cm-library-pull --force          # Overwrite conflicts (repo wins)
c-bpm-cm-library-pull --only-skills    # Pull only skills
c-bpm-cm-library-pull --only-agents    # Pull only agents
c-bpm-cm-library-pull --only-commands  # Pull only commands
c-bpm-cm-library-pull --only-runbooks  # Pull only runbooks
c-bpm-cm-library-pull --verbose        # Detailed output
```

### Push (local → repo)

```bash
c-bpm-cm-library-push                          # Push all c-bpm-items
c-bpm-cm-library-push --dry-run                # Preview what would change
c-bpm-cm-library-push --force                  # Overwrite conflicts (local wins)
c-bpm-cm-library-push --message "custom msg"   # Custom commit message
c-bpm-cm-library-push --only-skills            # Push only skills
c-bpm-cm-library-push --verbose                # Detailed output
```

### Conflict Detection

Both scripts track a SHA256 baseline per item in `~/.claude/.c-bpm-library-sync`. When an item has changed on **both** sides (locally and in the repo) since the last sync, it is flagged as a conflict and **skipped**:

```
  X skills/c-bpm-sk-foo (CONFLICT: changed locally AND in repo)

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
# (z.B. neuen Skill in ~/.claude/skills/c-bpm-sk-foo/ anlegen)
c-bpm-cm-library-push

# Auf Maschine B: Items synchronisieren
c-bpm-cm-library-pull
```

## Usage in Prompts

Reference these definitions in your prompts to Claude Code CLI:

- *"Use the Bash secure script standard to implement the installer."*
- *"As the Orchestrator, check the available MCP servers and provide an MCP Availability Handoff."*

## External Skill Packs

The n8n skill pack is maintained in a <a href="https://github.com/czlonkowski/n8n-skills" target="_blank">separate repository</a>. Use `bcgasl --n8n` to install it.

## License

This library is provided under the MIT License. See the `LICENSE` file for details.
