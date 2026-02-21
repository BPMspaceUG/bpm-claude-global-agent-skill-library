# Team Orchestration for Skill Development

Full agent team orchestration workflow for building, refactoring, and optimizing multiple skills in parallel with Codex-reviewed quality gates and milestone-tracked lifecycle.

## Table of Contents

- [GitHub Issue Tracking Rules](#github-issue-tracking-rules)
- [Phase 0 — Discovery & Environment Scan](#phase-0--discovery--environment-scan)
- [Phase 1 — Analysis & Team Planning](#phase-1--analysis--team-planning)
- [Phase 2 — Spawn Agent Team](#phase-2--spawn-agent-team)
- [Phase 3 — Plan Approval (Dual Gate)](#phase-3--plan-approval-dual-gate)
- [Phase 4 — Implementation](#phase-4--implementation)
- [Phase 5 — Codex Review & Verification](#phase-5--codex-review--verification)
- [Phase 6 — PR & Synthesis](#phase-6--pr--synthesis)
- [Codex Rules](#codex-rules)

---

## GitHub Issue Tracking Rules

### Issue Types

Only two issue types:

- **BUG** — Skill is broken, triggers incorrectly, gives wrong guidance
- **FEATURE** — New skill, optimization, forking, restructuring

No labels. No tags. Issue type is the only classifier.

### One Issue Per Skill Change

Each discrete skill change gets its own issue. All phases of work are documented as comments on the issue itself. No separate plan files.

### Milestone-Based Lifecycle

Every issue progresses through milestones in strict order:

```
new → planned → plan-approved → implemented → reviewed → review-approved → DONE
```

| Milestone | Set By | Meaning |
|-----------|--------|---------|
| `new` | Team Lead | Issue created, not yet planned |
| `planned` | Teammate | Plan submitted as issue comment |
| `plan-approved` | Team Lead + Codex | Both reviewed and approved the plan |
| `implemented` | Teammate | Skill files created/modified |
| `reviewed` | Codex | Codex review completed, results posted as issue comment |
| `review-approved` | Team Lead + Codex | Both approved the final result |
| `DONE` | **Human only** | Final sign-off — agents NEVER set this |

### Rules

- One milestone at a time per issue — no skipping
- `plan-approved` requires BOTH Team Lead AND Codex approval
- `DONE` is ONLY set by humans — agents must never set this milestone
- Always check existing issues before creating new ones to avoid duplicates

---

## Phase 0 — Discovery & Environment Scan

### Inventory Existing Skills

```
~/.claude/skills/           — Custom and local skills
~/.claude/plugins/          — Installed marketplace skills (READ ONLY)
```

- List all `my-` prefixed skills (custom)
- List all non-prefixed skills (originals)
- Identify skills without `my-` counterparts (candidates for forking)
- Identify orphaned `my-` skills (originals removed)

### Check MCP Servers

- GitHub MCP is **required** — abort if unavailable
- Check for Context7 MCP (key-value store for shared state)

### Read Project Context

- Read `CLAUDE.md` at project root for project-specific rules
- Read global `~/.claude/CLAUDE.md` for cross-project rules
- Note any skill-related rules (naming conventions, quality standards)

### Fetch Existing GitHub Issues

- List all open issues to understand current state
- Check for issues that overlap with planned work

---

## Phase 1 — Analysis & Team Planning

### Skill Analysis

For each skill in scope, analyze across these dimensions:

| Dimension | What to Look For |
|-----------|-----------------|
| **Segregation** | Is the original untouched? Does the `my-` version exist? |
| **Frontmatter** | Name correct? Description includes triggers? Provenance noted? |
| **Progressive Disclosure** | SKILL.md under 500 lines? References split out? |
| **Duplication** | Same info in SKILL.md and references? |
| **Lean Structure** | No README.md, CHANGELOG.md, or other clutter? |
| **Examples** | Concrete code/usage examples, not verbose explanations? |
| **Constraints** | Actionable MUST/MUST NOT, not vague guidelines? |

### Create GitHub Issues

- Create one issue per skill to create/fork/optimize
- Set initial milestone to `new`
- Group issues by logical teammate assignment

### Determine Team Size

- Minimum: 2 teammates
- Maximum: 6 teammates
- **No overlapping skills** — each skill belongs to exactly one teammate's scope
- If two improvements touch the same skill, assign them to the same teammate

### Present to User and WAIT

Present a summary:

1. **Skill inventory** — what exists, what's missing, what needs work
2. **Issues created** — per-skill breakdown
3. **Proposed team** — teammate names, responsibilities, assigned issues
4. **Estimated complexity** — per teammate

**STOP and WAIT for user confirmation before spawning teammates.**

---

## Phase 2 — Spawn Agent Team

### Model Policy

Choose the cheapest model that can handle the task:

| Model | When to Use |
|-------|------------|
| **Haiku** (default) | Single-skill changes, forking, documentation, minor optimizations |
| **Sonnet** | Complex multi-reference skills, architectural restructuring |
| **Opus** | Only if both Haiku and Sonnet fail at the task |

Start with Haiku. Escalate only when needed.

### Teammate Naming

Use descriptive role-based names:

- `skill-forker` — Forking originals to `my-` versions
- `skill-writer` — Creating new skills from scratch
- `skill-refactorer` — Restructuring existing custom skills
- `reference-builder` — Creating/updating reference files

### Teammate Instructions

Each teammate receives:

1. **Scope** — Exactly which skills they own
2. **Boundaries** — Skills they must NOT touch (especially originals)
3. **Issue numbers** — Which GitHub issues they are responsible for
4. **Segregation reminder** — Originals are READ ONLY, all changes go to `my-` versions
5. **Skills to load** — `my-bpm-skill-optimizer` for naming/workflow conventions, `skill-creator` for creation process
6. **First action** — Submit a plan as an issue comment BEFORE any implementation

---

## Phase 3 — Plan Approval (Dual Gate)

### Teammate Submits Plan

The teammate posts a plan as a comment on their assigned issue. The plan must include:

- **Skill name** — With `my-` prefix
- **Files to create/modify** — List every file
- **Changes description** — What will change and why
- **Origin tracking** — Which original this derives from (if forking)
- **Verification plan** — How to confirm the skill triggers correctly

### Dual Review

1. **Team Lead reviews** — Checks scope, naming convention, segregation of duty
2. **Codex reviews** — Run:
   ```bash
   codex exec --skip-git-repo-check "Review this skill development plan. Check for: naming convention (my- prefix), segregation of duty (original untouched), frontmatter quality, progressive disclosure, no unnecessary files. Plan: <plan content>"
   ```

### Approval

Both Team Lead AND Codex must approve. Move to milestone: `plan-approved`.

### Auto-Reject Conditions

- Missing `my-` prefix
- Plan modifies original skill files
- No verification plan
- Missing provenance in description (for forks)

---

## Phase 4 — Implementation

### Development Rules

- **Fork before modify** — never edit originals in place
- **Follow skill-creator conventions** — frontmatter, progressive disclosure, lean structure
- **Load `skill-creator`** for creation guidance and `my-bpm-skill-optimizer` for custom rules
- **Stay within assigned scope** — do not modify skills outside your boundaries
- **Commit incrementally** with descriptive messages

### Milestone Update

When implementation is complete, move issue to milestone: `implemented`.

---

## Phase 5 — Codex Review & Verification

### Codex Skill Review

```bash
codex exec --skip-git-repo-check "Review this Claude Code skill for quality. Check for:
1. Frontmatter: name and description are clear, description includes trigger conditions
2. Progressive disclosure: SKILL.md under 500 lines, references split out properly
3. No duplication between SKILL.md and reference files
4. Examples are concrete and minimal, not verbose explanations
5. Constraints are actionable (MUST/MUST NOT), not vague guidelines
6. No unnecessary files (README.md, CHANGELOG.md, etc.)
7. Naming convention: my- prefix for custom skills
8. Segregation: original skill untouched
Skill content: <skill content>"
```

### Verification Checks

| Check | How |
|-------|-----|
| Skill triggers correctly | Test with sample prompts that should activate the skill |
| Original untouched | `diff` original vs. current state — must be identical |
| `my-` prefix | Directory and frontmatter `name:` both use `my-` prefix |
| No clutter | No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md etc. |

### Approval

Both Team Lead AND Codex must approve. Move to milestone: `review-approved`.

---

## Phase 6 — PR & Synthesis

### Final Report

Present a synthesis report to the user:

1. **Skills created/modified** — Per-teammate breakdown
2. **Issue numbers** — All issues and their current milestones
3. **Codex review results** — Summary of findings
4. **Remaining work** — Any issues deferred or requiring follow-up

### Human Sign-Off Required

- Do NOT move any issues to `DONE` — only humans do that
- Present the results and await instructions

---

## Codex Rules

### Invocation

Codex is invoked ONLY via:

```bash
codex exec --skip-git-repo-check "<review prompt>"
```

Never use interactive mode. Never skip Codex review at mandatory gates.

### Mandatory Review Gates

Codex review is required at exactly 2 gates:

1. **Plan approval** (Phase 3) — Reviews the development plan
2. **Skill review** (Phase 5) — Reviews the implemented skill

### If Codex Is Unavailable

- **STOP** all work at that gate
- **Notify the user** immediately
- **Do NOT proceed** without Codex review — the dual-gate requirement is non-negotiable

### Logging

All Codex responses must be logged as comments on the relevant GitHub issue. This creates an audit trail of all review decisions.
