---
name: c-bpm-cm-goal-issue
description: "Overnight goal run — unattended issue processing, nachtlauf, run all open issues while the user is offline, autonomous goal issue execution. Loops Codex-gated teams per batch until every in-scope issue meets its DoD."
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Glob, Grep, LS, Task, Teammate, SendMessage
---

# /c-bpm-cm-goal-issue — Overnight Goal Run

You are the GOAL LEAD. You run unattended, typically overnight.

Model selection for yourself and for every teammate is owned solely by
`c-bpm-sk-llm-selection`. This command never names a model or a version.

$ARGUMENTS

---

## AUTONOMY CONTRACT (overrides every invoked command)

- The user is offline. The GOAL LEAD **never asks the user** anything — no
  questions, no confirmations, no approval requests, no escalations.
- The GOAL LEAD **never waits for user confirmation** at any gate, in this command
  or in any command it invoked — `/c-bpm-cm-openissues-team` carries the same
  no-confirmation contract (#116), and it is overridden here regardless.
- Codex is the counterpart, not the user: every review gate goes to Codex, and
  Codex output is run and tested, never trusted on sight.
- Unresolvable question or ambiguity → take the most pragmatic assumption, post
  it as an issue comment prefixed `ASSUMPTION:`, and continue.
- Never block, never abort the run. A stuck issue becomes `documented-blocked`,
  not a stopped run.
- Delegation and segregation of duty stay intact: teammates implement, Codex
  reviews, the GOAL LEAD coordinates. `DONE` is human-only and no agent ever
  sets it.

---

## G0 — SCOPE & CONTEXT REBUILD (from scratch, no cached context)

1. `git pull --rebase`; on conflict, stop the batch, comment the conflict on the
   affected issues, continue with the next batch.
2. Owner and repo come from `git remote -v` — never guessed.
3. Resolve scope from `$ARGUMENTS`:
   - explicit issue numbers (`112 113 117`)
   - `label:<name>`
   - any other filter expression passed through to `gh`
   - **Default scope (no arguments): every open issue in milestone `new`.**
4. Rebuild context from scratch — no memory of previous runs is assumed:
   `CLAUDE.md`, the repo's main log/README, and for every in-scope issue its
   body **and** all comments via `gh api .../issues/<n>` and
   `gh api .../issues/<n>/comments`.
5. External documentation is fetched only when a concrete gap blocks work.

---

## G1 — PLANNING: DEPENDENCY GRAPH → BATCHES

1. Build a dependency graph from issue cross-references and expected file
   overlap. Two issues touching the same file are dependent.
2. Topologically sort the graph into batches of 2–6 issues with no file overlap
   inside a batch.
3. Per-issue skill selection follows the Phase 3 skill table of
   `/c-bpm-cm-openissues-team` — referenced, never duplicated here.
4. Post the batch plan as a comment on every in-scope issue before execution.

---

## G2 — BATCH EXECUTION

For each batch, in topological order:

- Invoke `/c-bpm-cm-openissues-team` with the batch's issue numbers.
- That command owns the full milestone lifecycle and its three Codex gates
  (plan, test design, implementation). They are inherited, not re-implemented.
- The autonomy contract above overrides its user-confirmation points.
- Teammates never commit. Commits happen centrally in G3.

---

## G3 — PER-ISSUE COMMIT (direct to main)

Policy conflict PC-2, ratified: the Issue #112 spec wins for THIS command.

- The GOAL LEAD commits, teammates never do.
- An issue is committed only once it reaches the `test-approved` milestone.
- **One commit per issue**, message `Issue #<N>: <summary>`, pushed directly to
  `main` — no PRs, no feature branches, no batching of unrelated issues.
- `git commit` + `git push` run after the issue's own tests are green.
- `DONE` is human-only: the GOAL LEAD never sets it, not even after pushing.

---

## G4 — GOAL LOOP

1. After each batch, re-fetch the scope — issues created or re-opened during the
   run join the next batch.
2. **Exit condition: the loop exits once every in-scope issue either meets its DoD or is `documented-blocked`.**
3. Stall guard: two consecutive batches with zero progress on an issue → post an `ASSUMPTION:` / blocker comment, mark that issue `documented-blocked`, and stop working it. This guarantees the loop terminates.

**Definition of Done (DoD), per issue:** tests green and milestone
`test-approved`; all Codex findings addressed or answered in the issue; the
commit pushed to `main`; every assumption documented as an issue comment.

---

## G5 — FINAL REVIEW & MORNING REPORT

1. Final devil's-advocate pass over the whole run via `c-bpm-sk-devils-advocate`
   (that skill owns its own review ladder). Findings become new issues.
2. Write the morning report to `SUMMARY-<YYYYMMDD>-<HHMM>.md` in the repo root
   and leave it untracked.

   **Precedence for this single artifact:** the Issue #112 spec (an explicit
   user directive) **takes precedence** over the generic no-side-car rule below.
   The GitHub Issues remain the **authoritative** record: every per-issue fact —
   plan, assumption, review verdict, blocker — is posted as an **issue comment**
   FIRST, and the SUMMARY is only a user-mandated aggregation of what is already
   in the issues, never an agent-invented plan file. The ban in the block below
   targets agent-invented side-car docs; it is not waived for anything else.

3. Report contents: per issue → final milestone, commit SHA, DoD status,
   assumptions, blockers; plus the devil's-advocate findings and the new issues
   filed from them.

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
