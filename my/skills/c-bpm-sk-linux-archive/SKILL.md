---
model: opus
name: c-bpm-sk-linux-archive
description: "Archive host config — backup dotfiles, save tool configs, host backup, restore setup, config snapshot. Backs up to bpm-{hostname} GitHub repo."
enforcement: block
intentPatterns: "archive host config;;backup (dotfiles|config);;config snapshot;;backup (my |this )?(host|server) (config|setup)"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Linux Archive — Host Config Backup

Back up host configurations to `BPMspaceUG/bpm-{hostname}` so installations and config changes are traceable and recoverable.

## When to Use

- After installing a new tool (CLI, MCP server, etc.)
- After changing a configuration file
- When setting up a new host from scratch (restore)
- Periodic config sync check

## Repo Pattern

Every host gets a private repo: `BPMspaceUG/bpm-{HOSTNAME}`

```
bpm-{HOSTNAME}/
  configs/           # Config file backups, mirroring source paths
    glow/            # ~/.config/glow/
    codex/           # ~/.codex/
    claude/          # Selected ~/.claude/ configs (NOT secrets)
    ...
  installed-tools.md # Manifest of manually installed tools
  README.md
```

## Workflow: Archive After Install

Run after installing a tool or changing a config:

```
1. Detect hostname:    HOSTNAME=$(hostname)
2. Ensure repo cloned: ~/bpm-${HOSTNAME}/
3. Copy config files to configs/<toolname>/
4. Update installed-tools.md manifest
5. Git add, commit, push
```

### Step 1 — Detect and Clone

```bash
HOSTNAME=$(hostname)
REPO_DIR="$HOME/bpm-${HOSTNAME}"

if [ ! -d "$REPO_DIR" ]; then
  gh repo clone "BPMspaceUG/bpm-${HOSTNAME}" "$REPO_DIR"
fi
```

### Step 2 — Archive Config

```bash
TOOL_NAME="<toolname>"
CONFIG_SOURCE="<path-to-config>"

mkdir -p "${REPO_DIR}/configs/${TOOL_NAME}"
cp -r "${CONFIG_SOURCE}" "${REPO_DIR}/configs/${TOOL_NAME}/"
```

### Step 3 — Update Manifest

Add or update the row in `installed-tools.md`:

| Tool | Version | Install Method | Binary Location | Config Location |
|------|---------|---------------|-----------------|-----------------|
| name | version | how installed | where binary is | `configs/name/` → `~/.config/name/` |

### Step 4 — Commit and Push

```bash
cd "$REPO_DIR"
git add configs/ installed-tools.md
git commit -m "Archive ${TOOL_NAME} config"
git push
```

## Workflow: Restore Config

To restore a tool's config on a fresh host:

```bash
HOSTNAME=$(hostname)
REPO_DIR="$HOME/bpm-${HOSTNAME}"
gh repo clone "BPMspaceUG/bpm-${HOSTNAME}" "$REPO_DIR"

# Restore specific tool config
cp "${REPO_DIR}/configs/glow/glow.yml" ~/.config/glow/glow.yml
```

## What to Archive

### MUST archive
- Tool configs: `~/.config/<tool>/`, `~/.<tool>/config`
- Installed-tools manifest with versions and install methods
- MCP server configurations (`~/.claude/settings.json`, `~/.claude/settings.local.json`)
- Claude hooks config (part of `settings.json`)
- Shell customizations (`.bashrc` additions, `.profile`)
- Codex config (`~/.codex/config.toml`)

### MCP Server Configs

MCP server definitions live in:
- `~/.claude/settings.local.json` (mcpServers key)
- `~/bpm-mcp-windows-linux-sub/` (dedicated MCP config repo)

Archive the Claude settings files (secrets-stripped) to `configs/claude/`:

```bash
# Strip potential secrets from settings before archiving
python3 -c "
import json, re, sys
with open('$HOME/.claude/settings.json') as f:
    d = json.load(f)
# settings.json has no secrets typically, archive as-is
with open('${REPO_DIR}/configs/claude/settings.json', 'w') as f:
    json.dump(d, f, indent=2)
"
```

For MCP servers with API keys in env vars: archive the structure but NOT the secrets.

### MUST NOT archive
- Secrets, API keys, tokens, `.env` files with credentials
- Auth files (`auth.json`, session tokens)
- Large binaries, cache dirs, `node_modules/`
- Anything in `.gitignore`

### Secrets Check

Before committing, verify no secrets are staged:

```bash
git diff --cached --name-only | xargs grep -lE '(sk-|api_key|password|token|secret)' 2>/dev/null
```

If matches found: **STOP**, remove the file, add to `.gitignore`.

## Integration with Memory

After archiving, update the installed-tools table in MEMORY.md:

```markdown
## Installed Tools (track here + in bpm-{HOSTNAME})

| Tool | Version | Location | Config |
|------|---------|----------|--------|
| new-tool | x.y.z | `/path/to/bin` | `~/.config/tool/` |
```

## Codex Review Gate

Before executing any destructive or irreversible operation (config backup, git commit, git push), submit plan to Codex for review:

```bash
codex exec --skip-git-repo-check "Review this archive plan: <plan>. Check: no secrets exposed, correct file selection, follows project conventions. Approve or reject."
```

If Codex is unavailable, try the fallback chain: Codex → Gemini (`gemini` CLI) → any available model. If ALL unavailable: STOP and notify the user.

## Constraints

- MUST use `bpm-{HOSTNAME}` naming pattern (matches `c-bpm-sk-linux-audit` / `c-bpm-sk-linux-admin`)
- MUST check for secrets before every commit
- MUST NOT store binaries in the repo — only configs and manifests
- MUST update `installed-tools.md` with every new tool
- MUST update MEMORY.md installed-tools table
