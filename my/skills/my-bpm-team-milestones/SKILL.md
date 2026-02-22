---
name: my-bpm-team-milestones
description: Central milestone-based lifecycle for agent team orchestration. Defines workflow states, transition rules, Codex gate patterns, and audit trail requirements. Referenced by all team commands (my-experteam-openissues, my-refactor-repo, refactor_repo) and team-capable skills (my-flightphp-pro, my-skill-optimizer).
---

# Milestone-Based Issue Lifecycle

Milestones track issue progress through the agent team workflow. Each issue has exactly ONE milestone at a time representing its current state.

## Milestone Definitions

| Milestone | Set By | Meaning |
|-----------|--------|---------|
| `new` | Team Lead | Issue created, not yet planned |
| `planned` | Team Lead | Agent submitted a plan (posted as issue comment) |
| `plan-approved` | Team Lead + Codex | Both reviewed and approved the plan |
| `test-designed` | Team Lead | Agent submitted test design as issue comment |
| `test-design-approved` | Team Lead + Codex | Both approved test design |
| `implemented` | Team Lead | Code written, agent reports completion |
| `tested-success` | Team Lead | All tests pass |
| `tested-failed` | Team Lead | Tests fail — bounces back with documented reason |
| `test-approved` | Team Lead + Codex | Final automated gate — independent verification passed |
| `DONE` | **Human only** | Final sign-off. Agents NEVER set this. |

## Compact Lifecycle (for simpler workflows)

Skills without a test-design phase (e.g., skill development) may use:

| Milestone | Set By | Meaning |
|-----------|--------|---------|
| `new` | Team Lead | Issue created |
| `planned` | Team Lead | Plan submitted |
| `plan-approved` | Team Lead + Codex | Plan approved |
| `implemented` | Team Lead | Code written |
| `reviewed` | Codex | Codex review completed |
| `review-approved` | Team Lead + Codex | Both approved |
| `DONE` | **Human only** | Agents NEVER set this |

## Lifecycle Flow (Full)

```
new -> planned -> plan-approved -> test-designed -> test-design-approved
  -> implemented -> tested-success / tested-failed -> test-approved -> DONE
```

On failure: `tested-failed` bounces back to `planned` (wrong approach) or `implemented` (code bug). Team Lead documents WHY in an issue comment.

## Rules (Non-Negotiable)

1. **One milestone at a time** per issue — no skipping states
2. **Dual approval required** at every gate — Team Lead AND Codex must both approve
3. **`DONE` is human-only** — agents must NEVER set this milestone
4. **No labels, no tags** — Issue Type + Milestone is the only tracking mechanism
5. **One issue per discrete change** — all phases documented as comments on that issue
6. **Audit trail** — every Codex response posted as comment on the GitHub Issue
7. **Check existing issues** before creating new ones to avoid duplicates

## Phase 0: Create Milestones

At the start of any team workflow, create ALL lifecycle milestones via GitHub MCP. Skip any that already exist. Use the full or compact set depending on the workflow.

## Codex Gate Patterns

### Gate 1: Plan Approval (planned -> plan-approved)

```bash
codex exec --skip-git-repo-check "Review this implementation plan for Issue #<N>. \
Plan: <plan-summary>. \
REQUIREMENTS: 1) Test coverage must be included. 2) Changes scoped to assigned files. \
3) Risk assessment present. 4) Rollback strategy present. \
Approve or reject with specific reasons."
```

Post result as issue comment. If BOTH approve -> move to `plan-approved`.

### Gate 2: Test Design Approval (test-designed -> test-design-approved)

```bash
codex exec --skip-git-repo-check "Review test design for Issue #<N>. \
Tests: <test-description>. \
Check: edge cases covered, meaningful assertions, no false positives, \
adequate coverage, follows project test framework. Approve or reject."
```

Post result as issue comment. If BOTH approve -> move to `test-design-approved`.

### Gate 3: Test Verification (tested-success -> test-approved)

```bash
codex exec --skip-git-repo-check "Verify implementation and test results for Issue #<N>. \
Changes: <summary>. \
Check: tests passing legitimately, no false positives, test coverage adequate, \
code quality acceptable. Approve or reject."
```

Post result as issue comment. If BOTH approve -> move to `test-approved`.

### If Codex Unavailable

**STOP. Notify user. Do NOT proceed without Codex review.**

## Milestone Transitions via GitHub MCP

Move an issue to a new milestone:
```
mcp__github__issue_write(method: "update", owner: "...", repo: "...",
  issue_number: N, milestone: <milestone_number>)
```

Get milestone numbers:
```
gh api repos/{owner}/{repo}/milestones
```

## Integration

This skill is referenced by:
- `/my-experteam-openissues` — open issues team workflow
- `/my-refactor-repo` — repo refactoring team workflow
- `/refactor_repo` — repo refactoring team workflow (original)
- `my-flightphp-pro` — Flight PHP team orchestration
- `my-skill-optimizer` — skill development team orchestration

Each referencing skill/command adds domain-specific review criteria on top of these shared patterns.
