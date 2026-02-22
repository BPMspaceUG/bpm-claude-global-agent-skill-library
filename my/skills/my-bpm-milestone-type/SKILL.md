---
name: my-bpm-milestone-type
description: Enforce milestone lifecycle AND issue type on every GitHub issue. Ensures milestones exist, every issue has exactly one milestone, and every issue has a type label (bug or enhancement, always lowercase). Use to audit and fix repos for compliance. Successor to my-bpm-team-milestones.
---

# Milestone & Type Enforcement

Every GitHub issue MUST have:
1. **Exactly one milestone** — tracking lifecycle state
2. **Exactly one type label** — `bug` or `enhancement` (always lowercase)

## Issue Type Labels

| Label | Use When |
|-------|----------|
| `bug` | Something is broken, incorrect, or regressed |
| `enhancement` | New feature, improvement, or refactoring |

### Normalization Rules

- Always **lowercase**: `bug` not `Bug`, `enhancement` not `Enhancement`
- If a repo has uppercase variants (`Bug`, `Enhancement`), rename them to lowercase
- Each issue has exactly ONE type — not both, not neither
- No other type labels (no `feature`, `fix`, `task` — only `bug` or `enhancement`)

### Create/Normalize Type Labels

```bash
# Create lowercase labels (skip if exist)
gh label create bug --description "Something is broken" --color "d73a4a" 2>/dev/null || true
gh label create enhancement --description "New feature or improvement" --color "a2eeef" 2>/dev/null || true

# Delete uppercase variants if they exist (after migrating issues)
# gh label delete Bug --yes 2>/dev/null || true
# gh label delete Enhancement --yes 2>/dev/null || true
```

### Migrate Uppercase to Lowercase

```bash
# Find issues with uppercase labels and fix them
for issue in $(gh issue list --label "Bug" --json number -q '.[].number' 2>/dev/null); do
  gh issue edit "$issue" --remove-label "Bug" --add-label "bug"
done
for issue in $(gh issue list --label "Enhancement" --json number -q '.[].number' 2>/dev/null); do
  gh issue edit "$issue" --remove-label "Enhancement" --add-label "enhancement"
done
# Then delete the uppercase labels
gh label delete Bug --yes 2>/dev/null || true
gh label delete Enhancement --yes 2>/dev/null || true
```

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

### Compact Lifecycle (simpler workflows)

| Milestone | Set By | Meaning |
|-----------|--------|---------|
| `new` | Team Lead | Issue created |
| `planned` | Team Lead | Plan submitted |
| `plan-approved` | Team Lead + Codex | Plan approved |
| `implemented` | Team Lead | Code written |
| `reviewed` | Codex | Codex review completed |
| `review-approved` | Team Lead + Codex | Both approved |
| `DONE` | **Human only** | Agents NEVER set this |

### Lifecycle Flow

```
new -> planned -> plan-approved -> test-designed -> test-design-approved
  -> implemented -> tested-success / tested-failed -> test-approved -> DONE
```

On failure: `tested-failed` bounces back to `planned` (wrong approach) or `implemented` (code bug).

## Audit Procedure

When auditing a repo, check ALL of these:

### Step 1: Milestones Exist

```bash
# List existing milestones
gh api repos/{owner}/{repo}/milestones --jq '.[].title'

# Create missing ones
for ms in new planned plan-approved test-designed test-design-approved implemented tested-success tested-failed test-approved DONE; do
  gh api repos/{owner}/{repo}/milestones --method POST -f title="$ms" 2>/dev/null || true
done
```

### Step 2: Type Labels Exist (lowercase)

```bash
# Check for labels
gh label list --json name --jq '.[].name' | grep -E '^(bug|enhancement|Bug|Enhancement)$'

# Create if missing, normalize if uppercase
gh label create bug --description "Something is broken" --color "d73a4a" 2>/dev/null || true
gh label create enhancement --description "New feature or improvement" --color "a2eeef" 2>/dev/null || true
```

### Step 3: Every Open Issue Has Milestone + Type

```bash
# Find issues without milestone
gh issue list --json number,title,milestone,labels --jq '.[] | select(.milestone == null) | "\(.number) \(.title)"'

# Find issues without type label
gh issue list --json number,title,labels --jq '.[] | select(([.labels[].name] | map(select(. == "bug" or . == "enhancement")) | length) == 0) | "\(.number) \(.title)"'
```

### Step 4: Fix Non-Compliant Issues

For each issue missing a milestone:
- Set to `new` if freshly created
- Set to appropriate state if work already exists

For each issue missing a type:
- Determine if `bug` or `enhancement` from title/body
- Add the label

### Step 5: Report

Output a compliance table:

```
Repo: {owner}/{repo}
Milestones: ✓ all 10 exist
Type labels: ✓ bug + enhancement (lowercase)
Open issues: 12
  With milestone: 12/12 ✓
  With type label: 11/12 ✗
  Missing type: #42 "Add logging"
```

## Rules (Non-Negotiable)

1. **One milestone at a time** per issue — no skipping states
2. **Dual approval required** at every gate — Team Lead AND Codex must both approve
3. **`DONE` is human-only** — agents must NEVER set this milestone
4. **Every issue gets a type** — `bug` or `enhancement`, no exceptions
5. **Always lowercase** — normalize on sight
6. **One issue per discrete change** — all phases documented as comments
7. **Audit trail** — every Codex response posted as comment on the GitHub Issue
8. **Check existing issues** before creating new ones to avoid duplicates

## Codex Gate Patterns

### Gate 1: Plan Approval (planned -> plan-approved)

```bash
codex exec --skip-git-repo-check "Review this implementation plan for Issue #<N>. \
Plan: <plan-summary>. \
REQUIREMENTS: 1) Test coverage must be included. 2) Changes scoped to assigned files. \
3) Risk assessment present. 4) Rollback strategy present. \
Approve or reject with specific reasons."
```

### Gate 2: Test Design Approval (test-designed -> test-design-approved)

```bash
codex exec --skip-git-repo-check "Review test design for Issue #<N>. \
Tests: <test-description>. \
Check: edge cases covered, meaningful assertions, no false positives, \
adequate coverage, follows project test framework. Approve or reject."
```

### Gate 3: Test Verification (tested-success -> test-approved)

```bash
codex exec --skip-git-repo-check "Verify implementation and test results for Issue #<N>. \
Changes: <summary>. \
Check: tests passing legitimately, no false positives, test coverage adequate, \
code quality acceptable. Approve or reject."
```

### If Codex Unavailable

**STOP. Notify user. Do NOT proceed without Codex review.**

## Milestone Transitions via GitHub MCP

```
mcp__github__issue_write(method: "update", owner: "...", repo: "...",
  issue_number: N, milestone: <milestone_number>)
```

Get milestone numbers:
```bash
gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number) \(.title)"'
```

## Supersedes

This skill replaces `my-bpm-team-milestones`. All references to the old skill should use this one instead.
