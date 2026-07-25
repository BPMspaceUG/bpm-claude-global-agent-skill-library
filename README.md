# BPMspace Claude Global Skills Library

Skills, agents, commands and hooks for the Claude Code CLI, installed once per
machine and reused across every project. This README is the operating manual —
install, run, test. Architecture and the reasoning behind the conventions live
in [CLAUDE.md](CLAUDE.md).

## 1. What This Is

Every custom item follows the `c-{org}-{type}-{name}` convention — `c-bpm-sk-`
for skills, `c-bpm-cm-` for commands, `c-bpm-ag-` for agents. The prefix lets
several organisations' libraries coexist in one `~/.claude/`, and lets an
upstream item and a customised fork live side by side.

| Path | Holds | Format |
|------|-------|--------|
| `my/skills/` | custom skills | directory per skill with `SKILL.md` |
| `my/commands/` | slash commands | one flat `.md` per command |
| `my/agents/` | teammate role definitions | one flat `.md` per agent |
| `my/hooks/` | enforcement hooks (TypeScript source, built to `dist/`) | `.ts` → `.mjs` |
| `my/shared/` | text blocks stamped into many items | `.md` fragments |
| `runbooks/`, `templates/` | standard operational guides, issue/PR templates | `.md` |

Items under `my/` are distributed by `c-bpm-cm-library-pull` / `-push`;
everything else is repo-local reference material.

## 2. Installation

### Fresh install

```bash
git clone git@github.com:BPMspaceUG/bpm-claude-global-agent-skill-library.git ~/bpm-claude-global-agent-skill-library
cd ~/bpm-claude-global-agent-skill-library
./install --global --with-c-bpm-library   # installs bcgasl + the c-bpm-library CLIs
c-bpm-cm-library-pull                     # copies all c-bpm items into ~/.claude/
sudo ./install-hooks --system             # one-time, multi-user: hooks to /usr/local/bin
./install-hooks                           # per-user: register the hooks in settings.json
```

Without a clone, the installer can be piped — the repo is cloned on the first
`c-bpm-cm-library-pull`:

```bash
curl -fsSL https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/install | bash -s -- --global --with-c-bpm-library
```

`bcgasl` installs the standard (non-`c-bpm`) agents, skills, runbooks and
templates from a **pinned release tarball**, so it does not deliver the latest
`c-bpm` items — `c-bpm-cm-library-pull` is the path for those.

### Hooks

`install-hooks` installs `dist/*.mjs` and registers them as `PreToolUse` hooks.
Currently one hook ships: `issue-write-gate`, wired to the `Bash`,
`mcp__github__issue_write` and `mcp__github__create_issue` matchers — it denies
any GitHub Issue creation that lacks a milestone or a single `bug`/`enhancement`
type label.

It registers the hook in **both** standard settings paths
(`~/.claude/settings.json` and `~/.config/claude/settings.json`)
**where they exist — a missing settings file is skipped, not created**
(see #65 / #76). Ensure both files exist before running it if your Claude builds
read different paths. The script is idempotent; `--dry-run` previews and `--uninstall` reverses
it.

### Required environment

- `gh` authenticated for the target repositories (`gh auth status`)
- `codex` CLI on `PATH` — the review authority for every gate
- `~/.env` (user level, never a project `.env`) with `OPENROUTER_API_KEY` for
  the substitute-Judge tier
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` for the agent-team commands
- `bats` for the test suite, `node` for the hooks

### Verification

```bash
ls ~/.claude/skills | grep -c '^c-bpm-sk-'            # 1. skills landed
command -v bcgasl c-bpm-cm-library-pull               # 2. CLIs on PATH
# 3. hook registered in every settings file that exists
for f in ~/.claude/settings.json ~/.config/claude/settings.json; do \
  [ -f "$f" ] && { grep -q issue-write-gate "$f" && echo "OK $f" || echo "GAP $f"; }; done
echo '{"tool_name":"Bash","tool_input":{"command":"gh issue create --title p --body p"},"cwd":"'"$PWD"'"}' \
  | node ~/.claude/hooks/dist/issue-write-gate.mjs    # 4. must print "deny"
gh auth status && codex --version                      # 5. review authority reachable
```

Step 3 must report the hook in **every settings file that exists**. If only one
of the two exists, that is the #65 / #76 gap — fix it before relying on the
gate, do not read it as a successful install.

### Updating an existing installation

After changes land on `main`, every machine needs all three steps — pulling the
repo alone leaves the installed copies under `~/.claude/` stale, which is how
superseded content keeps executing (see #114):

```bash
cd ~/bpm-claude-global-agent-skill-library && git pull
c-bpm-cm-library-pull    # refresh the installed copies in ~/.claude/
./install-hooks          # idempotent re-registration of the current hooks
```

Then re-run the verification block above. The same "only existing settings
files are updated" caveat (#65 / #76) applies to the re-registration.

## 3. How the Agent Teams Work

The team commands implement segregation of duty as a capability, not a
guideline. The Team Lead coordinates, reviews and approves but writes no code;
teammates implement and report; the Lead never approves alone.

**Codex is the review authority.** Three gates are Codex-gated —
plan approval, test-design approval, and test verification — each invoked
through `c-bpm-sk-devils-advocate`, which fetches the live Issue, sanitises the
payload, and falls back down a substitute-Judge ladder when Codex is
unreachable. A gate never passes on a missing review.

**Milestones are the state machine.** Every issue moves
`new` → `planned` → `plan-approved` → `test-designed` →
`test-design-approved` → `implemented` → `tested-success` / `tested-failed` →
`test-approved`, updated at each transition. `DONE` is **human-only** — agents
never set it. Every issue also carries exactly one type label, `bug` or
`enhancement`; `issue-write-gate` enforces both mechanically.

**Communication is Issues-only.** The plan, rejected plans, progress and every
decision go in the Issue body or comments — never into side-car `.md` files.
Codex is handed an Issue reference, not a pasted document.

**Teammate lifecycle** is currently written policy, not yet encoded in the
commands: finished teammates should be shut down rather than left idle, and
fresh spawns are preferred over reusing a context-rotted teammate. Tracked in
#120.

Entry points:

- `/c-bpm-cm-openissues-team` — interactive run over the open issues, user sees
  the plan before the team spawns.
- `/c-bpm-cm-goal-issue` — unattended run (typically overnight); never waits for
  user confirmation, loops Codex-gated batches until every in-scope issue meets
  its definition of done.

## 4. Model Policy

`c-bpm-sk-llm-selection` is the **single source of truth** for model selection
and orchestration. No skill, command or script may hard-wire a model name or
version — not for Codex (`codex exec` runs bare, with no `-m`), not for
Claude, not for the OpenRouter fallback tier. This README therefore names zero
model versions, and `tests/bash/c-bpm-sk-codex-flag.bats` fails the build if a
pin reappears (see #98).

## 5. Testing

```bash
./tests/run_tests.sh     # requires bats on PATH; equivalent to: bats tests/bash/
bats tests/bash/readme-guards.bats   # a single suite
```

The suite is offline and deterministic. It covers the installer and sync scripts
(`install.bats`, `sync-dedup.bats`, `bpm-bootstrap.bats`,
`c-bpm-cm-library-compare.bats`), the enforcement hook
(`c-bpm-sk-issue-write-gate.bats`), and drift guards over the skills and
commands themselves — model-version pins, Codex invocation hygiene, the review
loop, the Issues-only communication block, the goal-issue command, and this
README.

**Known red:** 9 of the 29 `c-bpm-sk-issue-write-gate.bats` fixtures fail
because the runner never exports `FIXTURE_REPO` — a test-harness defect, not a
hook defect, tracked in #100. A clean checkout is expected to show exactly those
failures and no others. End-to-end execution of skills (as opposed to static
guards) is not covered yet; that harness is #122.

## 6. Key Commands

Slash commands, invocable in any Claude Code session once installed:

| Command | Purpose |
|---------|---------|
| `/c-bpm-cm-openissues-list` | Open-issues dashboard with status, type and milestone; creates missing milestones |
| `/c-bpm-cm-openissues-team` | Spawn a teammate team to work the open issues in parallel; Codex-reviewed, tests mandatory |
| `/c-bpm-cm-goal-issue` | Unattended goal run; loops Codex-gated teams per batch until every in-scope issue is done |
| `/c-bpm-cm-refactor-repo` | Spawn a teammate team for parallel refactoring; Codex-reviewed, milestone-tracked |
| `/c-bpm-cm-library-pull` | Sync c-bpm items from this repo into `~/.claude/` |
| `/c-bpm-cm-library-push` | Sync c-bpm items from `~/.claude/` into this repo; auto-commits and pushes |
| `/c-bpm-cm-library-compare` | Show which c-bpm items differ between `~/.claude/` and the repo; optionally repair |
| `/c-bpm-cm-skill-creator` | Create a skill; detects an existing `c-bpm-sk-` version and delegates to the optimizer |
| `/c-bpm-cm-skill-optimizer` | Fork, customise or upgrade an existing skill under Codex-reviewed quality gates |

Shell CLIs installed by `./install`: `bcgasl` (standard items from the pinned
release) and `c-bpm-cm-library-pull` / `-push` / `-compare` — the sync engines
behind the slash commands above. `./install-hooks` stays in the repo. Common
sync flags: `--dry-run`, `--verbose`, `--force`, `--clean`, `--only-skills`,
`--only-agents`, `--only-commands`; push adds `--message`, compare `--repair`.

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

## External Skill Packs

The n8n skill pack is maintained in a <a href="https://github.com/czlonkowski/n8n-skills" target="_blank">separate repository</a>. Install it with `bcgasl --n8n`.

## License

MIT. See the `LICENSE` file.
