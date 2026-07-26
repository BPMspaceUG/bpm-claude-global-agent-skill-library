---
name: c-bpm-sk-library-manager
description: "Library management — c-bpm convention, sync items, push pull library, manage skills, library help. Central knowledge hub for c-bpm- item convention and synchronisation."
enforcement: block
intentPatterns: "c-bpm (convention|sync|library);;(push|pull) (c-bpm |)library;;library (push|pull|sync);;manage (skills|commands) library"
user-invocable: false
allowed-tools: Read, Grep, Glob, Bash
---

# Library Manager

Central knowledge hub for managing `c-bpm-` prefixed custom items across all artefact types. Coordinates push/pull synchronisation via the Git repository.

## The `c-bpm-` Convention

**All custom/user-created items use the `c-bpm-` prefix with a type infix.** This applies to ALL artefact types:

| Type | Prefix | Location | Format | Example |
|------|--------|----------|--------|---------|
| Skills | `c-bpm-sk-` | `~/.claude/skills/c-bpm-sk-<name>/` | Directory with `SKILL.md` | `c-bpm-sk-flightphp-pro/SKILL.md` |
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
├── Is it a command/runbook?
│   └── Create as c-bpm-{type}-<name>.md in appropriate directory
└── After creation:
    └── Run c-bpm-cm-library-push to version it
```

## Creating New Items

### New Skill
1. Use `c-bpm-sk-skill-creator` or `c-bpm-sk-skill-optimizer`
2. Creates `~/.claude/skills/c-bpm-sk-<name>/SKILL.md`
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

## Structural Scorecard for `c-bpm-sk-*` Audits (#54)

Every cohesion audit of the skill library scores each skill on six binary dimensions
and reports a library-wide roll-up. **Threshold for 'well-formed': ≥ 5/6.**

1. **Trigger discoverability** — em-dash description, parses via the `lib.sh` keyword extractor
2. **Intent coverage** — ≥ 3 distinct `intentPatterns` regexes
3. **Tool boundary** — `allowed-tools` declared OR `disable-model-invocation: true`
4. **Argument awareness** — `argument-hint` if `user-invocable: true` AND the body documents `$ARGUMENTS`
5. **Token efficiency** — SKILL.md ≤ 200 lines OR uses linked `references/*.md`
6. **No content duplication** — no paragraph > 3 lines repeated verbatim in another skill

Library-wide metrics: description conformance %, frontmatter field-set consistency %,
trigger collision count, library context budget (bytes), lifecycle coverage %.

**Audits are scored, not impressionistic.** An audit that reports "looks fine" or
"looks redundant" without the scorecard is not an audit. Measurement detail, scoring
notes, and the regression rule: [`references/skill-audit-policy.md`](references/skill-audit-policy.md).

## Principled Splits (do not merge) (#55)

Several skill families look redundant to a surface-level review and are deliberate,
principled splits with **zero `intentPattern` overlap**:

| Family | Members | Split axis |
|---|---|---|
| Grill family | `c-bpm-sk-grill-me`, `c-bpm-sk-grill-me-issue`, `c-bpm-sk-grill-claude-issue` | target × asker × output medium |
| Skill lifecycle pair | `c-bpm-sk-skill-creator`, `c-bpm-sk-skill-optimizer` | lifecycle stage (create → optimize handoff) |
| Linux trio | `c-bpm-sk-linux-audit`, `c-bpm-sk-linux-admin`, `c-bpm-sk-linux-archive` | lifecycle stage (find → fix → preserve) |

**Rule:** any proposal to merge a pair above must first refute that row's split axis in
writing, in the Issue. "Looks redundant" is not a refutation. Evidence and the
per-family rationale: [`references/skill-audit-policy.md`](references/skill-audit-policy.md).

## Must-Stay Rule (F3) (#56)

When refactoring a skill for progressive disclosure, this content **MUST remain in
SKILL.md** and must never be moved to `references/`:

- Frontmatter
- Skill purpose statement (≤ 3 lines)
- Trigger conditions / when-to-use
- Safety constraints / refusal rules
- Required tool-call order / phase gates
- Non-obvious defaults
- Critical fallback chain
- MVP scope exclusions
- Cross-skill protocol references (link only)

**May move to `references/`:** detailed examples, long bash blocks, reference tables,
multi-agent boilerplate, per-tech checklists, historical notes, tutorials.

Every refactor is verified against the three-check protocol in
[`references/skill-audit-policy.md`](references/skill-audit-policy.md) — a body that can
no longer answer "when do I invoke this?" or "what must I never do here?" on its own has
lost Must-Stay content and must have it moved back.

## Conflict Handling

- `c-bpm-cm-library-pull` uses `git pull --ff-only` — fails safely on conflicts
- `c-bpm-cm-library-push` pulls first, then pushes — detects conflicts early
- Deleted items: shown as warnings, **never auto-deleted** (safety)
- Resolution: manual `cd ~/bpm-claude-global-agent-skill-library && git status`

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
