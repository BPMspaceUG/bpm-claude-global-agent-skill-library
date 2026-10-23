# BPMspace Claude Global Skills Library

A small library of custom commands and skills for the Claude Code CLI, installed
once per machine and used in any repository, plus the scripts that keep the
installed copies in sync with this repo. Architecture and conventions live in
[CLAUDE.md](CLAUDE.md).

## 1. What This Is

Process skills come from Matt Pocock's plugin `mattpocock-skills@mattpocock`
(grilling, to-spec, to-tickets, implement, tdd, code-review, domain-modeling,
research, retro and the rest). This library holds only what that plugin does
not cover. Every custom item follows the `c-{org}-{type}-{name}` convention —
`c-bpm-sk-` for skills, `c-bpm-cm-` for commands, `c-bpm-ag-` for agents — so
several organisations' libraries can coexist in one `~/.claude/`.

| Path | Holds | Format |
|------|-------|--------|
| `my/skills/` | custom skills | directory per skill with `SKILL.md` |
| `my/commands/` | slash commands | one flat `.md` per command |
| `my/agents/` | teammate role definitions (currently none) | one flat `.md` per agent |
| `my/hooks/` | the agent cleanup hook and its settings fragment | `c-bpm-hk-*.sh` + `c-bpm-hooks.json` |
| `my/hosts/` | per-host inventory written by the sync scripts | `.txt` |

## 2. Installation

### Fresh install

```bash
git clone git@github.com:BPMspaceUG/bpm-claude-global-agent-skill-library.git ~/bpm-claude-global-agent-skill-library
cd ~/bpm-claude-global-agent-skill-library
./install --global --with-c-bpm-library   # installs bcgasl + the c-bpm-library CLIs
c-bpm-cm-library-pull                     # copies all c-bpm items into ~/.claude/
```

Without a clone, the installer can be piped — the repo is cloned on the first
`c-bpm-cm-library-pull`:

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --global --with-c-bpm-library
```

`bcgasl` installs the standard (non-`c-bpm`) items from a **pinned release
tarball**; `c-bpm-cm-library-pull` is the path for the current `c-bpm` items.

### Required environment

- `gh` authenticated for the target repositories (`gh auth status`)
- `codex` CLI on `PATH` — the read-only reviewer used by `c-bpm-cm-spec-oneshot` and `c-bpm-sk-gogo`
- Matt Pocock's plugin installed: `claude plugin install mattpocock-skills@mattpocock`, then `/c-bpm-cm-pocock-update` once so the model may call its skills
- `bats` for the test suite

### Verification

```bash
ls ~/.claude/commands | grep -c '^c-bpm-cm-'            # 1. commands landed (expect 5)
ls ~/.claude/skills | grep -c '^c-bpm-sk-'              # 2. skills landed (expect 1)
command -v bcgasl c-bpm-cm-library-pull                 # 3. CLIs on PATH
gh auth status && codex --version                       # 4. reviewer reachable
```

### Updating an existing installation

After changes land on `main`, every machine needs both steps — pulling the repo
alone leaves the installed copies under `~/.claude/` stale:

```bash
cd ~/bpm-claude-global-agent-skill-library && git pull
c-bpm-cm-library-pull    # refresh the installed copies in ~/.claude/
```

### The hooks

`c-bpm-cm-library-pull` installs two hooks, `c-bpm-hk-agent-cleanup-guard` and
`c-bpm-hk-skills-refresh`, and
registers it in `~/.claude/settings.json` (plus `~/.config/claude/settings.json`
when that file exists). Re-running the pull is idempotent and also replaces the
older stand-alone `agent-cleanup-guard.sh` registration.

| Event | What happens |
|-------|--------------|
| `TeammateIdle` | The teammate that just finished its turn is stopped by Claude Code (`continue: false`). |
| `Stop` | The user sees a line listing every teammate, subagent and shell still in flight. Open teammates and shells get one request to `TaskStop` them; never twice in a row. |
| `SessionStart` (startup, /clear) | Claude is told to run `ListAgents` and stop leftover teammates before answering. |
| `SessionStart` (startup, resume) | The installed Pocock skills are unlocked at once, without network. At most once per 24 h a detached worker updates the plugin, unlocks again and runs `c-bpm-cm-library-pull`; the result applies from the next session. Log: `~/.claude/hooks/c-bpm-hk-skills-refresh.log`. |

Restart Claude Code after the first pull so the registration is loaded. The
cleanup hook writes every payload it sees, without the assistant's text, to
`~/.claude/hooks/c-bpm-hk-agent-cleanup-guard.log`. Both logs are capped at 256 KiB.

### Removing the former enforcement hooks

Until 2026-10-23 this library registered `PreToolUse` and `SessionStart` hooks
(`issue-write-gate`, `plan-doc-gate`, `codex-sod-tracker`). They are gone from
the repo, but a host that installed them still has the registrations in its
settings files. Clean such a host once:

```bash
rm -rf ~/.claude/hooks/dist
for f in ~/.claude/settings.json ~/.config/claude/settings.json; do
  [ -f "$f" ] || continue
  python3 - "$f" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); hooks = d.get("hooks", {})
names = ("issue-write-gate", "plan-doc-gate", "codex-sod-tracker")
for ev in list(hooks):
    kept = []
    for entry in hooks[ev]:
        entry["hooks"] = [h for h in entry.get("hooks", []) if not any(n in h.get("command", "") for n in names)]
        if entry["hooks"]:
            kept.append(entry)
    if kept: hooks[ev] = kept
    else: del hooks[ev]
json.dump(d, open(p, "w"), indent=2); print("cleaned", p)
EOF
done
```

## 3. Items

| Item | Invoke as | Purpose |
|------|-----------|---------|
| `c-bpm-cm-spec-oneshot` | `/c-bpm-cm-spec-oneshot [major\|minor\|patch]` | Write or version a self-contained specification under `/specification/` and the overnight build prompt under `/prompts/`. One optional grilling round with Rob; every other open point is decided in the spec or delegated to Codex. |
| `c-bpm-sk-gogo` | `/c-bpm-sk-gogo [spec issue \| label]` | Unattended overnight run over the ready, unblocked tickets of the current repo: agent team, one worktree per ticket, Codex plan and implementation reviews, draft PR per integration branch. `TEAMMATE.md` is the teammate contract. |
| `c-bpm-cm-pocock-update` | `/c-bpm-cm-pocock-update [--check] [--no-update]` | Manual, immediate Pocock update and unlock; the `c-bpm-hk-skills-refresh` hook does the same at session start. |
| `c-bpm-cm-library-pull` | `/c-bpm-cm-library-pull` or the CLI | Sync c-bpm items from this repo into `~/.claude/` |
| `c-bpm-cm-library-push` | `/c-bpm-cm-library-push` or the CLI | Sync c-bpm items from `~/.claude/` into this repo; auto-commits and pushes |
| `c-bpm-cm-library-compare` | `/c-bpm-cm-library-compare` or the CLI | Show which c-bpm items differ between `~/.claude/` and the repo; optionally repair |

How the two overnight flows relate: `c-bpm-cm-spec-oneshot` produces a spec and
a build prompt that rebuilds a whole project from an empty directory; the run is
started by pasting that prompt into `claude`. `c-bpm-sk-gogo` works the ticket
graph of an existing repo (tickets from `/to-spec` and `/to-tickets` carrying the
"ready for agent" label). Both never ask a human; both route decisions to Codex.

Shell CLIs installed by `./install`: `bcgasl` (standard items from the pinned
release) and `c-bpm-cm-library-pull` / `-push` / `-compare` — the sync engines
behind the slash commands above. Common sync flags: `--dry-run`, `--verbose`,
`--force`, `--clean`, `--only-skills`, `--only-agents`, `--only-commands`; push
adds `--message`, compare `--repair`.

### Sync conflict handling

Both sync scripts track a SHA256 baseline per item in
`~/.claude/.c-bpm-library-sync`. An item changed on **both** sides since the
last sync is flagged and skipped rather than silently overwritten.

| Scenario | Pull | Push |
|----------|------|------|
| Only repo changed | Updates local | — |
| Only local changed | — | Updates repo |
| Both changed | **CONFLICT** (skipped) | **CONFLICT** (skipped) |
| Both changed + `--force` | Repo wins | Local wins |
| No baseline (first sync) | Updates local | Updates repo |

## 4. Testing

```bash
./tests/run_tests.sh     # requires bats on PATH; equivalent to: bats tests/bash/
bats tests/bash/readme-guards.bats   # a single suite
```

The suite is offline and deterministic. It covers the installer and sync
scripts (`install.bats`, `sync-dedup.bats`, `sync-only-flags.bats`,
`bpm-bootstrap.bats`, `c-bpm-cm-library-compare.bats`,
`c-bpm-hosts-inventory.bats`), drift guards over this README
(`readme-guards.bats`), content guards over the custom items
(`c-bpm-items.bats`) and the agent cleanup hook with its installation
(`c-bpm-hk-agent-cleanup-guard.bats`) and the skills refresh hook (`c-bpm-hk-skills-refresh.bats`).

## 5. Maintenance

- After editing any root script, refresh `checksums.sha256` (command in CLAUDE.md).
- No item pins a model name or version; `readme-guards.bats` and
  `c-bpm-items.bats` fail if one appears.
- When a build's `RETRO.md` finds a recurring gap in `c-bpm-cm-spec-oneshot` or
  `c-bpm-sk-gogo`, file an issue here and fix the item here, never in a
  project repo.
- The former enforcement hooks, agents, runbooks, templates and skills were removed on
  2026-10-23 in favour of the Pocock plugin; git history is the archive.

## External Skill Packs

The n8n skill pack is maintained in a <a href="https://github.com/czlonkowski/n8n-skills" target="_blank">separate repository</a>. Install it with `bcgasl --n8n`.

## License

MIT. See the `LICENSE` file.
