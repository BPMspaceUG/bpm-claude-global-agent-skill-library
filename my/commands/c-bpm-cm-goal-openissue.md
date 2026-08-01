---
name: c-bpm-cm-goal-openissue
description: "Autonomous end-to-end delivery of open issues — goal openissue, drive issues to test-approved, resume from any milestone, unattended issue pipeline run. Scope comes from /c-bpm-cm-openissues-team, never a SPEC file; each issue enters the pipeline at its current milestone and is driven to test-approved. DONE is human-only."
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Glob, Grep, LS, Task, Teammate, SendMessage
---

# /c-bpm-cm-goal-openissue — Autonomous Open-Issue Delivery

Autonomous end-to-end delivery of open work items. The work is NOT defined in a
SPEC file — it is defined by issues retrieved through
`/c-bpm-cm-openissues-team`. This command drives each issue through the
milestone chain from wherever it currently stands up to `test-approved`.

Model selection for yourself and for every teammate is owned solely by
`c-bpm-sk-llm-selection`. This command never names a model or a version.

$ARGUMENTS

---

## SETUP — FIRST, before anything else

```bash
mkdir -p decisions reviews
```

---

## MILESTONE MODEL (ordered)

| Milestone | Meaning |
|---|---|
| `new` | Freshly created, unplanned (mandatory on creation) |
| `planned` | Plan exists |
| `plan-approved` | Plan cleared by judge/gate |
| `test-designed` | Test design created |
| `test-design-approved` | Test design cleared |
| `implemented` | Implementation finished |
| `tested-success` | Test result: pass |
| `tested-failed` | Test result: fail |
| `test-approved` | Tests accepted — **agent end state** |
| `DONE` | Closed — set by a **human ONLY**, never by an agent |
| `CANCELLED` | Deliberate abort — terminal, set by a **human ONLY**. Reachable from any state except `DONE`. |

Hard rules on milestones:

- **NEVER set an issue to `DONE` or `CANCELLED`.** Both are human-only
  transitions. An issue you cannot finish is reported as `documented-blocked`
  in a comment — never cancelled by you.
- `test-approved` is the terminal state for this command.
- Issues in `test-approved`, `DONE`, or `CANCELLED` are out of scope and are
  not touched.
- Set the milestone after each completed stage, so an interrupted run is
  resumable from the issue state alone.

---

## ARGUMENTS

- Optional: one or more issue numbers (space- or comma-separated), and/or a
  label filter.
- If issue numbers are given, ONLY those issues are in scope. Nothing else is
  touched — the state filter below does not apply. If a given issue does not
  exist or is already `test-approved`/`DONE`/`CANCELLED`, say so explicitly and
  continue with the remaining ones.
- If no arguments are given, the scope is resolved automatically (see below).

## SCOPE RESOLUTION (no issue numbers given)

- In scope: every issue whose milestone is NOT `test-approved`, NOT `DONE`, and
  NOT `CANCELLED`.
- This deliberately includes issues stuck in an intermediate milestone from an
  aborted or crashed earlier run — those are the most important ones.
- Resolve the scope via `/c-bpm-cm-openissues-team` at the start of the run and
  re-resolve before each new work batch (new issues may have appeared).
- State the resolved scope explicitly before starting: issue ID, title, current
  milestone, and the stage you will resume at.

## RESUME LOGIC — per issue, enter the pipeline at the current milestone

| Current milestone | Resume action |
|---|---|
| `new` | verify open points, then write the plan |
| `planned` | get the plan reviewed/approved |
| `plan-approved` | create the test design |
| `test-designed` | get the test design approved |
| `test-design-approved` | implement (TDD) |
| `implemented` | run the tests |
| `tested-failed` | debug, fix, re-test (systematic-debugging) |
| `tested-success` | get the tests reviewed and approved |

Do NOT redo earlier stages blindly. Verify that the artefact of the previous
stage actually exists and is coherent; if it is missing or contradicts the
current code, treat the issue as if it were at the last milestone whose
artefact is intact, say so, and restart from there.

---

## BATCH PLANNING (before the work starts, and again after each re-resolve)

- Analyse dependencies across all in-scope issues.
- Produce an explicit execution plan that splits the issues into a **parallel
  set** (independent, no shared files/contracts) and a **sequential chain**
  (dependencies, shared modules, migrations, contract changes).
- Use subagent-driven-development for the parallel set; run the sequential
  chain strictly in order.
- Surface this split in the conversation before executing it.

---

## DONE — all of the following hold AND each has been demonstrated in this
conversation, because the evaluator reads only what you surfaced here:

1. For every in-scope issue, all open/ambiguous points (contracts, endpoints,
   payloads, states) are answered against the live API or the live system, the
   issue is updated with the verified facts (description or comment), and that
   change is committed.
2. PLAN.md exists, covers every in-scope issue including the
   parallel/sequential split, and its review verdict is APPROVED
   (TOTAL >= 20, no dimension below 4).
3. Every deliverable named in the in-scope issues exists; you showed the tree.
4. The test suite runs and exits 0; you showed the output.
5. The implementation review verdict is APPROVED under the same rubric.
6. The acceptance criteria of each in-scope issue are demonstrated live in
   this conversation (run it, show the output) — not merely asserted.
7. `reviews/scores.md` holds every round, `git status` is clean, and every
   finished issue carries the milestone `test-approved`. No issue was set to
   `DONE`.

---

## ROLES

- **You are the implementer.** Nothing else writes code.
- **Codex is the reviewer and the oracle.** It runs read-only and never writes
  code. Invoke it exclusively through `c-bpm-sk-devils-advocate` — that skill
  owns the canonical sanitized invocation, the live-Issue payload, and the
  substitute-Judge ladder defined in `c-bpm-sk-llm-selection`. Never hand-roll
  a Judge CLI invocation in this command (see issues #118/#119); the OpenRouter
  tier is part of that ladder, not a flag pinned here.

---

## WORKING RULES

- **Never ask the user anything.** Nobody is awake. There is no human until
  morning.
- When blocked or uncertain, ask Codex instead of stopping. Append question
  and answer to `decisions/qa.md`, take the answer as the decision, continue.
- If an issue is underspecified, do not guess silently: ask Codex, record the
  decision in `decisions/qa.md`, and write the resulting interpretation back
  into the issue.
- **Never expand the scope on your own.** If work on an in-scope issue reveals
  additional work, create a separate issue in milestone `new` instead of doing
  it — unless it is strictly required to satisfy the in-scope acceptance
  criteria.
- Capture every review into `reviews/`, append scores to `reviews/scores.md`,
  commit `reviews/`.
- Commit before every review and after every green test run. Reference the
  issue ID in every commit message. No pull requests — push directly to
  `main`.
- Use the installed skills: `/c-bpm-cm-openissues-team` for issue retrieval
  and milestone changes; writing-plans and executing-plans for the planning
  stage; test-driven-development while implementing; systematic-debugging on
  `tested-failed`; requesting-code-review and receiving-code-review around
  each round; verification-before-completion before you claim anything is
  done; subagent-driven-development for the parallel set. Use
  `c-bpm-sk-devils-advocate` and `c-bpm-sk-auditor` for the reviewer-side
  framing.
- The models this build runs on have nothing to do with the models the
  product calls. Never wire the product to your own model, and never copy a
  build-time model name into source, config, prompts, tests or docs.
- If the same failure repeats three times, stop retrying. Write it to
  `decisions/blockers.md`, ask Codex for a different route, take it.

## TURN PROTOCOL

- End every turn with a per-issue table: issue ID, milestone at start of
  turn, milestone now, which of the seven DONE items hold, which do not, what
  you do next.
- Stop after 60 turns even if not done, and summarise the state per issue.

---

## PRECEDENCE — mandated run artifacts

The `PLAN.md`, `decisions/`, and `reviews/` files above are an **explicit user
directive for this command** and take precedence over the generic no-side-car
rule in the stamped block below — the same PC-2-style ratification as the
SUMMARY report in `/c-bpm-cm-goal-issue`. The GitHub Issues remain the
**authoritative** record: every per-issue fact — plan, decision, review
verdict, blocker — is posted as an **issue comment FIRST**, and these files are
user-mandated aggregations of what is already in the issues, never a
replacement for them. The ban below targets agent-invented side-car docs and
is not waived for anything else.

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
