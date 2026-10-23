# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **BPMspace** global skills library for Claude Code CLI: a small set of
custom commands and skills, installed once per machine and used in any repo, plus
the sync scripts that distribute them. Process skills (grilling, spec, tickets,
TDD, code review, domain modelling, research) come from Matt Pocock's plugin
`mattpocock-skills@mattpocock`; this library holds only what that plugin does not
cover.

All custom items use the `c-{org}-{type}-{name}` prefix convention
(`c-bpm-sk-` skills, `c-bpm-cm-` commands, `c-bpm-ag-` agents) and live under `my/`.

## Items

| Item | Type | Job |
|---|---|---|
| `c-bpm-cm-spec-oneshot` | command | Write or version a one-shot specification under `/specification/` plus the overnight build prompt under `/prompts/`. Rob is asked at most one grilling round; everything else is decided in the spec or delegated to Codex. |
| `c-bpm-sk-gogo` | skill | Unattended overnight run: implements every ready, unblocked ticket of the current repo with an agent team and Codex reviews (`TEAMMATE.md` is the teammate contract). |
| `c-bpm-cm-pocock-update` | command | Update the Pocock plugin and strip `disable-model-invocation: true` from every installed SKILL.md so Claude can call the skills itself. Re-run after every plugin update. |
| `c-bpm-cm-library-pull` / `-push` / `-compare` | command + CLI | Sync `my/` items between this repo and `~/.claude/`. |
| `c-bpm-hk-agent-cleanup-guard` | hook | Stops a teammate as soon as it finishes its turn (`TeammateIdle` → `continue: false`), shows the user what is still running at every turn end (`Stop`, from `background_tasks`), asks once for `TaskStop` on open teammates and shells, and demands an agent sweep at `SessionStart`. |

This is the only hook. `c-bpm-cm-library-pull` installs it: it copies
`my/hooks/c-bpm-hk-*.sh` to `~/.claude/hooks/` and merges
`my/hooks/c-bpm-hooks.json` into `~/.claude/settings.json` (and into
`~/.config/claude/settings.json` when that file exists), replacing any earlier
registration of the same script. Edit the hook here, never in `~/.claude/hooks/`;
`c-bpm-cm-library-push` does not carry hook edits back. The enforcement hooks
of the former library (issue gates, plan-doc gate, SoD tracker) were removed on
2026-10-23; the git history holds them and the former agents, runbooks and
skills.

## Architecture

```
bpm-claude-global-agent-skill-library/
├── my/
│   ├── skills/              # c-bpm-sk-<name>/SKILL.md (+ companion files)
│   ├── commands/            # c-bpm-cm-<name>.md (flat)
│   ├── agents/              # c-bpm-ag-<name>.md (currently empty)
│   ├── hooks/               # c-bpm-hk-<name>.sh + c-bpm-hooks.json (settings fragment)
│   └── hosts/<host>/        # per-host inventory, written by the sync scripts
├── c-bpm-cm-library-pull    # repo -> ~/.claude/
├── c-bpm-cm-library-push    # ~/.claude/ -> repo (commits and pushes)
├── c-bpm-cm-library-compare # diff both sides, --repair
├── bcgasl                   # pinned-release installer for the standard items
├── install                  # installs bcgasl + the c-bpm-cm-library CLIs
├── sync                     # copy engine used by bcgasl
├── lib.sh                   # shared functions (prefix handling, baselines, conflicts)
├── bpm-bootstrap.sh         # host bootstrap
├── checksums.sha256         # sha256 of the root scripts (update after editing them)
└── tests/bash/*.bats        # offline test suite, ./tests/run_tests.sh
```

### Naming convention

- `ITEM_PREFIX="c"`, `ORG_PREFIX="bpm"`; type codes `sk`, `cm`, `ag`, `hk` (`rb` for runbooks is a legacy code the sync scripts still accept; the library ships none).
- Installed copies keep the same name, so `/c-bpm-cm-spec-oneshot` is the slash
  command once `c-bpm-cm-library-pull` has run.
- Items without the `c-` prefix are upstream originals and are never edited here.

### Key patterns

- Never hardcode secrets; use `.env` files.
- Scripts are idempotent and run under `set -euo pipefail`.
- No item pins a model name or version. Build-time models (the Claude session,
  Codex) never appear in product code or specs; `c-bpm-cm-spec-oneshot` enforces
  that rule for the specs it writes.
- Everything written here is in English.

## Installation and workflow

```bash
curl -fsSL .../install | bash -s -- --global --with-c-bpm-library
c-bpm-cm-library-pull          # install or refresh the c-bpm items in ~/.claude/
c-bpm-cm-library-push          # after editing an item locally
c-bpm-cm-library-pull --dry-run
```

After editing any root script: `sha256sum lib.sh sync install c-bpm-cm-library-pull c-bpm-cm-library-push c-bpm-cm-library-compare bcgasl > checksums.sha256`.

## Testing

```bash
./tests/run_tests.sh      # bats tests/bash/
```

The suite is offline and deterministic: installer and sync behaviour, host
inventory scoping, README drift guards, and content guards for the three
custom items.

## Maintenance rule for the commands

When a build's `RETRO.md` or a spec review finds a recurring gap in
`c-bpm-cm-spec-oneshot` or `c-bpm-sk-gogo` itself, file an issue in this repo
and fix the item here. Never patch an installed copy inside a project repo.
