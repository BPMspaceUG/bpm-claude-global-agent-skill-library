---
model: opus
name: c-bpm-sk-grill-me-issue
description: >
  Refine a GitHub Issue through research, dedup detection, milestone validation,
  and relentless questioning. Issue exists first, then gets grilled. Use when
  user says "grill issue #N", "refine issue", or references an issue to improve.
argument-hint: "[issue-number or URL]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Grill Me — Issue Refiner

Refine an existing GitHub Issue through research, dedup detection, milestone
validation, and relentless questioning. The issue exists FIRST — then we grill.

**Difference from c-bpm-sk-grill-me**: The general griller stress-tests ideas and
outputs to the bpm-ideas Obsidian vault as MD files. This skill takes an existing
GitHub Issue and refines it in-place. The output is the updated issue itself —
body edits, comments, and new child issues — not a separate document.

## Phase 1 — Accept Issue

Parse the argument to extract the issue number:
- Accepted formats: `#42`, `42`, or full URL (`https://github.com/owner/repo/issues/42`)
- If no argument provided, ask: "Welches Issue soll ich grillen? Gib mir eine Nummer oder URL."
- Extract `{owner}/{repo}` from `git remote -v` (prefer `origin`, fall back to `upstream`)
- Validate the issue exists:
  ```bash
  gh issue view {number} --json number,title,body,comments,labels,milestone
  ```
- If not found: print error with the exact number tried and stop. Do not guess or create.
- Store the full JSON response as working context for all subsequent phases.

## Phase 2 — Research

Mandatory before asking any questions. Build context silently.

1. **Read the issue**: body, all comments, labels, milestone, assignees
2. **Fetch all open issues** for dedup/overlap analysis:
   ```bash
   gh api repos/{owner}/{repo}/issues?state=open&per_page=100 \
     --jq '.[] | select(.pull_request == null) | {number, title, labels: [.labels[].name], milestone: .milestone.title}'
   ```
3. **Milestone scan**:
   ```bash
   gh api repos/{owner}/{repo}/milestones --jq '.[] | {number, title}'
   ```
   - Check the target issue's milestone against the lifecycle
     (`new` -> `planned` -> `plan-approved` -> ... -> `DONE`)
   - No milestone: flag it — "Dieses Issue hat keinen Milestone — welcher passt?"
   - Milestone seems wrong for the issue's current state: flag it
4. **Codebase scan**: read files and functions referenced in the issue body
   (look for file paths, class names, function names, error messages)

## Phase 3 — Dedup Check

Compare the target issue against all open issues. Overlap signals (strongest first):
- Same milestone + label overlap (very strong — likely related or duplicate)
- Title keyword overlap (stemmed, ignoring stop words like "add", "fix", "update")
- Body keyword overlap (shared technical terms, identifiers, file paths)
- Label overlap (same type + same component = stronger signal)
- References to the same files or functions in the codebase

Scoring: if 2+ signals match, flag as potential overlap. If 3+, flag as likely
duplicate.

Present findings to user:
- "Issue #42 scheint sich mit #38 zu ueberschneiden — sollen wir die zusammenfuehren?"
- List each candidate with number, title, and specific overlap reasons
- If no overlaps found, state that explicitly: "Keine Duplikate oder Ueberlappungen gefunden."

Wait for user decision before proceeding. Do not auto-merge or auto-close.

## Phase 4 — Grill

Ask questions that the research could not answer. Follow the same interview
protocol as c-bpm-sk-grill-me:

- **One focused question at a time** — never bundle multiple questions
- **Challenge assumptions** — push deeper on vague answers
- **Call out contradictions** — reference specific earlier answers
- **No circular questions** — track what was asked, never retread

### Branch Tracking

Maintain a decision tracker throughout the session:

```
## Decision Branches
- [OPEN] Branch 1: Scope unclear — does this include migration?
- [RESOLVED] Branch 2: Target framework -> Flight PHP (per existing stack)
- [BLOCKED] Branch 3: API contract -> waiting on upstream spec
```

Statuses: **OPEN** (not yet resolved), **RESOLVED** (decided), **BLOCKED** (external dep).

### Question Archetypes

Rotate through these to ensure coverage:
- **Why this over alternatives?** — force trade-off articulation
- **What happens when X fails?** — probe error paths and edge cases
- **Who consumes this?** — clarify interfaces and downstream users
- **What changes if Y changes?** — test coupling assumptions
- **How do you know it works?** — demand testability criteria
- **What are you not saying?** — surface implicit assumptions

## Phase 5 — Issue Updates

Update the issue body with refined content. Triggers:
- Every 3rd resolved branch (incremental save)
- On stop signal ("Schalte den Grill aus")
- On natural completion (all branches resolved)

```bash
gh issue edit {number} --body "..."
```

Preserve the original issue content at the top. Add or update these sections
below the original text:

- `## Refined Requirements` — cleaned-up, specific, testable requirements
- `## Resolved Decisions` — branch resolutions with rationale (who decided, why)
- `## Edge Cases` — discovered edge cases and expected handling
- `## Open Questions` — unresolved branches carried forward for future grilling
- `## Acceptance Criteria` — concrete, verifiable criteria derived from grilling

Post a summary comment at session end:
```bash
gh issue comment {number} --body "..."
```

The comment should include: session date, branches resolved count, branches
remaining, and any new issues spawned with links.

## New Scope Discovery

When grilling reveals work outside the target issue's scope:

1. Ask: "Das geht ueber den Scope von Issue #{number} hinaus. Soll ich ein neues Issue anlegen?"
2. **Only create after explicit user confirmation**
3. Before creating: mandatory dedup check against all open issues
4. Use the repo's issue template if one exists (check `.github/ISSUE_TEMPLATE/`)
5. New issues get milestone `new` and appropriate type label (`bug`/`enhancement`)
6. **Hard limit: 3 new issues per session.** After 3, inform the user the session limit is reached. Suggest starting a new session if more issues are needed. Do NOT create more than 3 regardless of user request.

## Termination

Two paths to wrap-up:

- **"Schalte den Grill aus"** — stop grilling, proceed to Phase 6
- **All branches resolved** — natural completion, proceed to Phase 6

Both paths execute the full wrap-up protocol.

## Phase 6 — Wrap-up

1. **Final issue body update** with all refined content (Phase 5 format)
2. **Post summary comment** on the issue:
   - Branches resolved (count + list)
   - Branches unresolved (count + list)
   - New issues created (if any, with links)
3. **Codex Devil's Advocate** review:
   ```bash
   codex exec --skip-git-repo-check "Review this refined GitHub Issue #{number}: [title]. Refined content: [summary]. Challenge: 1) Are requirements complete and testable? 2) What edge cases are missing? 3) Is acceptance criteria clear? 4) Any scope creep?"
   ```
   Post the Codex response as an issue comment.
4. **Codex fallback chain**: `codex` -> `gemini` -> notify user that Devil's
   Advocate review must be done manually.

## Rules

- Never accept vague answers — push for specifics ("it depends" requires "on what exactly?")
- Never skip a branch because it seems obvious — obvious branches hide assumptions
- Call out contradictions with reference to earlier answers (quote them verbatim)
- Issue is updated continuously — session is interruption-safe at any point
- Always check milestones and labels for compliance with repo conventions
- One focused question at a time — never bundle multiple questions in one message
- If a question can be answered by reading code, read the code instead of asking
- Never modify labels or milestone without asking the user first
- Keep the original issue body intact — append refined sections below it
- Track all created issues to avoid exceeding the 3-per-session limit
