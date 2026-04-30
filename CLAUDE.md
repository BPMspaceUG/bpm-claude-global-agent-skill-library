# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is the **BPMspace** global skills library for Claude Code CLI. It contains task playbooks (skills), operational guides (runbooks), commands, and collaboration templates. All custom items use the `c-{org}-{type}-{name}` prefix convention (e.g., `c-bpm-sk-`, `c-bpm-cm-`) and are versioned under `my/`.

## Skills Are Absolute

By the convention this library establishes:

- **Skills** under `my/skills/c-bpm-sk-*` and their installed copies in `~/.claude/skills/` are the canonical home for process rules — how the agent works, when Codex is invoked, what gates apply, how phases transition, what the cycle policy is. Skills are versioned, reviewed, and distributed via `bcgasl` / `c-bpm-cm-library-pull`.

- **Memory** under `~/.claude/projects/*/memory/` is the home for user preferences, project facts, references to external systems, and verbatim user statements. By this library's convention, memory does not encode process rules.

- **CLAUDE.md** describes repository architecture and the conventions of this library. It does not redefine process rules; those live in the skills.

The operative Codex review pattern is defined in `c-bpm-sk-llm-selection`; issue #89 tracks correcting that skill to the Producer-LLM ↔ Codex-as-Judge loop with no cycle cap and no user escalation. Enforcement of this convention — write-time blocks on memory directories, install-time audits — is implemented in skills and hooks, not in this file.

## Architecture

### Directory Structure

```
bpm-claude-global-agent-skill-library/
├── my/                      # All c-bpm-prefixed custom items
│   ├── skills/              # Directories (c-bpm-sk-<name>/SKILL.md)
│   ├── commands/            # Flat files (c-bpm-cm-<name>.md)
│   └── runbooks/            # Flat files (c-bpm-rb-<name>.md)
├── runbooks/                # Standard operational guides
├── templates/               # Issue and PR templates
├── c-bpm-cm-library-pull    # Pull c-bpm-items from repo to local
├── c-bpm-cm-library-push    # Push c-bpm-items from local to repo
├── bcgasl               # Main install/update command
├── install              # Installer script
├── sync                 # Sync script
└── lib.sh               # Shared library functions
```

### The `c-{org}-{type}-{name}` Naming Convention

Custom items use the `c-{org}-{type}-{name}` pattern:
- `ITEM_PREFIX="c"`, `ORG_PREFIX="bpm"` with type codes: `sk` (skills), `cm` (commands), `rb` (runbooks)
- Example: `c-bpm-sk-bash-secure-script` (a skill), `c-bpm-cm-refactor-repo` (a command)
- This allows multiple organizations' libraries to coexist without conflicts
- Original/installed items (without `c-` prefix) keep their original name
- Two versions can coexist: original for reference, custom for use

### Key Patterns

- Never hardcode secrets; use `.env` files
- Scripts must be idempotent
- Use skills for domain knowledge (see `c-bpm-sk-llm-selection` for orchestration and MCP discovery)

## Installation

```bash
# Install bcgasl + c-bpm-library tools
curl -fsSL .../install | bash -s -- --global --with-c-bpm-library

# Then use
bcgasl                    # Install/update skills
c-bpm-cm-library-pull     # Pull c-bpm-items from repo
c-bpm-cm-library-push     # Push c-bpm-items to repo
```

## c-bpm-library Workflow

```bash
# Pull latest from repo
c-bpm-cm-library-pull

# After creating/modifying items locally
c-bpm-cm-library-push

# Preview without changes
c-bpm-cm-library-pull --dry-run
c-bpm-cm-library-push --dry-run
```

## Target Technology Stack (what skills in this library cover)

- **Bash** - Automation scripts with strict mode (`set -euo pipefail`)
- **PHP/Flight** - MVC backend framework
- **MariaDB** - Database with forward-only migrations
- **Redis** - Caching with namespaced keys and TTL policies
- **n8n** - Workflow automation
- **php-crud-api** - REST API generation

## Enforcement: Hooks, Not Wrappers

**Rule:** Cross-machine rules are enforced via Claude Code hooks and GitHub Actions — not via CLI wrappers, shims, or replacement binaries in `/usr/local/bin/`.

**Why:** wrappers are OS-dependent and require installing a separate shim on every machine for every rule. Hook configuration lives in this repo (`my/hooks/`) and is deployed consistently via `bcgasl` / `c-bpm-cm-library-pull`. GitHub Actions live in `.github/workflows/` and run server-side. Both centralise the enforcement logic; only the install-once step is per-machine.

### Required hook layers

| Layer | Mechanism | Catches |
|---|---|---|
| Claude Code `SessionStart` hook | `settings.json` → `hooks.SessionStart` (sources distributed via `my/hooks/`) | Loads project rules, host context, and required defaults at the start of every Claude session. |
| Claude Code `PreToolUse` hook | `hooks.PreToolUse` matchers on `Bash`, `Edit`, `Write`, and MCP tool names | Intercepts every code path that mutates external state — `gh issue create`, `git commit`, `gh api`, `curl`/`python` against GitHub REST/GraphQL, MCP tools that wrap GitHub. Blocks on rule violation. |
| GitHub Actions | `.github/workflows/*.yml` on `issues.opened`, `pull_request.opened`, `push` | Catches everything created outside Claude Code (web UI, raw API, other agents, other machines). Auto-corrects or comments. |

### Settings.json locations

The repo's install scripts write to **both** of the standard Claude Code settings paths so hooks fire regardless of which path the user's Claude Code build reads first:

- `~/.claude/settings.json`
- `~/.config/claude/settings.json`

Verify both exist after `bcgasl` / `c-bpm-cm-library-pull`. If only one is populated and the other Claude build is in use on a host, hooks will silently not fire.

### Minimal hook example (issue-create guard)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/gh-issue-create-guard.sh"
          }
        ]
      }
    ]
  }
}
```

The hook script reads the tool input (the bash command) from stdin/env, greps for `gh issue create` / `gh api .../issues` / `curl ... /issues` / `mcp__*__create_issue`, and exits non-zero with a clear stderr message if `--milestone` and a type label (`bug` or `enhancement`) are missing. See the authoritative Claude Code hooks docs for exact event names, matcher syntax, and stdin schema before implementing.

### Required coverage for issue creation

Every code path that creates a GitHub Issue must be intercepted:

1. `gh issue create` via Bash — `PreToolUse` on `Bash` matcher
2. `gh api repos/.../issues -X POST` via Bash — same matcher, broader regex
3. `curl` / `python` / any direct HTTP client hitting GitHub REST or GraphQL — same matcher, regex on URL
4. MCP-server issue creation (e.g., `mcp__github__create_issue`) — `PreToolUse` on the MCP tool-name matcher
5. `git`-trailer-triggered issue creation (rare) — `PreToolUse` + GitHub Action
6. Web UI / external clients / other agents — GitHub Action on `issues.opened`

If any of these paths can create an issue without milestone + type label, the rule is unenforced.

### Anti-patterns (do not do)

- `/usr/local/bin/gh-issue-create` wrapper script
- Shell function in `~/.bashrc` overriding `gh`
- Symlink replacing the real `gh` binary
- Per-machine install steps for enforcement logic beyond the one-time hook deployment
- Documentation-only "remember to set milestone" — must be machine-enforced

### When the audit finds a gap

If `/c-bpm-cm-openissues-list` finds a non-compliant issue:

1. Fix the issue immediately (set milestone + type)
2. File a bug identifying which hook layer was missing — this finding is itself auto-filed per the "every finding becomes an issue" rule (see auto-memory and `c-bpm-sk-milestone-type`)
