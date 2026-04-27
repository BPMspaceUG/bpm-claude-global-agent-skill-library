---
model: opus
name: c-bpm-sk-grill-claude-issue
description: "Codex grills Claude on an issue — grill claude, review claude's work, independent review, codex review issue. Reversed roles: Codex asks questions, Claude researches and answers."
enforcement: block
intentPatterns: "grill claude;;codex (review|grill|challenge);;independent review"
user-invocable: true
argument-hint: "[issue-number or URL]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, WebSearch, WebFetch
---

# Grill Claude — Issue Review

Codex grills Claude about a GitHub Issue. Reversed roles: Codex asks the
questions, Claude researches and answers. The user observes the exchange, then
confirms or rejects the verdict.

## Differentiation

| Skill | Who gets grilled? | Who asks? | Output |
|-------|-------------------|-----------|--------|
| `c-bpm-sk-grill-me` | User | Claude | Obsidian MD in bpm-ideas |
| `c-bpm-sk-grill-me-issue` | User | Claude | Issue body edits + comments |
| **c-bpm-sk-grill-claude-issue** | **Claude** | **Codex** | **Issue comments (Q&A audit trail)** |

### Three Scenarios

1. **Claude wrote the issue** — Codex challenges Claude's own work
2. **Issue was partially grilled with user** — Codex probes remaining gaps
3. **Issue not grilled yet** — Codex performs a full independent review

## Phase 1 — Accept Issue

Parse the argument to extract the issue number:
- Accepted formats: `#42`, `42`, or full URL (`https://github.com/owner/repo/issues/42`)
- If no argument provided, ask: "Which issue should Codex grill me on? Give me a number or URL."
- Extract `{owner}/{repo}` from `git remote -v` (prefer `origin`, fall back to `upstream`)
- Validate the issue exists:
  ```bash
  gh issue view {number} --json number,title,body,comments,labels,milestone
  ```
- If not found: print error with the exact number tried and stop. Do not guess or create.
- Store the full JSON response as working context for all subsequent phases.

## Phase 2 — Context Preparation

Build context before the grilling loop begins.

1. **Read issue body + all comments** — extract decisions, open questions, and prior
   Q&A from any earlier grill sessions
2. **Dynamically identify relevant skills**: scan `~/.claude/skills/` and
   `.claude/skills/` for skills whose name or description relates to the issue's
   domain (e.g., if the issue mentions "bash script", read `c-bpm-sk-bash-secure-script`).
   Read their SKILL.md content for reference patterns.
3. **Read codebase files** referenced in the issue body — file paths, function names,
   error messages, class names
4. **Package into the structured prompt schema** (see below) for the first Codex call

## Structured Codex Prompt Schema

### Input Fields (Claude to Codex)

```yaml
issue_number: 42
issue_title: "Add auth middleware"
issue_summary: "one-paragraph summary of the issue and its goals"
open_branches: ["unresolved points needing examination"]
resolved_branches: ["resolved points with decisions and rationale"]
asked_questions: ["all questions asked so far in this session"]
last_answer_summary: "Claude's last answer with evidence and citations"
contradictions: ["contradictions found between issue content and code"]
research_evidence: ["key findings from code, skills, and web research"]
question_budget_remaining: 10
followup_budget_remaining: 4
```

### Output Fields (Codex to Claude)

```yaml
question_kind: "why-this-over-alternatives"
branch: "authentication approach"
question: "Why JWT over session tokens given the existing session infra?"
why_this_question: "Issue claims stateless auth but code shows session store usage"
verdict: null  # or approve | approve-with-risks | needs-clarification | reject
```

When Codex returns a `verdict` instead of a question, the current branch closes.

## Phase 3 — Grilling Loop

Budgets:
- **Max 10 main questions** from Codex
- **Max 4 follow-ups** per main question
- Codex can end early by returning a verdict if satisfied

### Per-Round Protocol

1. **Claude calls Codex** with the structured prompt:
   ```bash
   codex exec --skip-git-repo-check -m gpt-5.2 "<structured prompt with all input fields>"
   ```
2. **Codex returns** a question (or verdict if satisfied on the current branch)
3. **Claude researches actively** — read code, grep patterns, consult relevant
   skills, run web searches. Use all available tools: Read, Grep, Glob, Bash,
   WebSearch, WebFetch.
4. **Claude posts Q&A as issue comment**:
   ```bash
   gh issue comment {number} --body "**Codex asks:** {question}

   **Claude answers:** {answer with evidence and file:line citations}"
   ```
5. **Update canonical state** — move resolved points, update budgets, track
   contradictions
6. **Loop** — next round with updated prompt

### Handling Disagreement

If Codex and Claude cannot agree after all follow-ups on a branch:
- Document as "unresolved" with both positions stated
- Move to the next main question
- Include in final summary for user decision

## Claude's Answer Behavior

Claude must research before answering. Never speculate.

| Question Type | Required Action |
|---------------|----------------|
| "How did you do it?" | Read code, verify implementation, cite file:line |
| "How would you do it?" | Consult skills, search web, reference known patterns |
| "Why this approach?" | Find alternatives, compare trade-offs, cite evidence |
| "What about edge case X?" | Grep for handling, read tests, check error paths |

**"I don't know" is always better than guessing.** If Claude cannot find evidence
after research, state that clearly with what was searched.

## Token Compaction Strategy

Keep a rolling canonical state, NOT the full transcript.

### What to Preserve (verbatim)

- Issue summary (immutable after Phase 2)
- Open branches and contradictions
- Latest research evidence with source pointers
- Budget counters
- Last 1-2 exchanges (for Codex continuity)

### What to Compact

- Closed branches: reduce to decision + rationale (one line each)
- Superseded research: drop detail, keep file:line pointers
- Resolved contradictions: keep resolution only

### Overflow Protocol

1. If approaching token limit: drop low-value research detail, keep source pointers
2. If still over budget: stop the loop with status `needs-human-compaction`
3. **Record ALL compaction events** in the audit trail:
   ```
   [COMPACTION] Round 5: Dropped research detail for branches 1-3, kept pointers
   ```

## Phase 4 — Verdict

Codex returns a verdict for each main question branch:

| Verdict | Meaning |
|---------|---------|
| `approve` | Branch is sound, no concerns |
| `approve-with-risks` | Acceptable but risks noted |
| `needs-clarification` | Insufficient evidence to judge |
| `reject` | Fundamental issue found |

Post a final summary comment on the issue:
```bash
gh issue comment {number} --body "## Codex Review Summary

| Branch | Verdict | Notes |
|--------|---------|-------|
| Auth approach | approve-with-risks | JWT valid but session fallback missing |
| Error handling | approve | Comprehensive coverage verified |
| ... | ... | ... |

**Overall:** [summary assessment]
**Unresolved:** [list or 'none']"
```

## Phase 5 — User Confirmation

Present the summary to the user after posting:

1. List each branch with its Codex verdict and key reasoning
2. Ask the user to confirm or reject each point
3. If user **confirms**: session complete
4. If user **rejects** specific points: offer handoff to
   `c-bpm-sk-grill-me-issue` for disputed points where the user gets grilled
   directly on those branches

## Codex Fallback Chain

1. **Primary**: `codex exec --skip-git-repo-check -m gpt-5.2 "<prompt>"`
2. **Fallback 1**: `gemini` CLI with equivalent prompt
3. **Fallback 2**: notify user that devil's advocate must be done manually —
   "Codex and Gemini unavailable. Run the review manually or retry later."

Test availability at session start. If primary fails, switch to fallback
immediately — do not retry the failed tool on subsequent rounds.

## Rules

- All Q&A documented as issue comments — full audit trail, no exceptions
- Claude must never fake answers — research actively or say "I don't know"
- Compaction events always logged in the audit trail
- One question at a time from Codex — never batch
- All content in English
- Do NOT modify the issue body (MVP scope — deferred)
- Do NOT create child issues (MVP scope — deferred)
- Do NOT run dedup checks (MVP scope — deferred)
- If a question can be answered by reading code, read the code before answering
- Track question and follow-up budgets strictly — stop when exhausted
