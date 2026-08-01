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

No run directories, no run files: every record of this run lives in GitHub
Issues (see BATCH PLANNING). The only setup is the orchestration label,
**ensure-then-verify**: create the `plan` label if missing, then verify it
exists with a read (`gh label list` or `gh api .../labels/plan`). Only an
"already exists" error is tolerable. If the verification read fails for any
reason (auth, API, network), the discriminator is unavailable — you MUST NOT
create a Plan Issue and MUST NOT proceed with multi-issue orchestration;
report `documented-blocked` on the affected issues instead. No verified
label, no Plan Issue, no silent fallback.

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
- An explicitly passed issue carrying the `plan` label is refused as a work
  item — report it as an orchestration artifact and continue with the
  remaining numbers. Plan Issues are never executable, on either entry path.
- If no arguments are given, the scope is resolved automatically (see below).

## SCOPE RESOLUTION (no issue numbers given)

- In scope: every issue whose milestone is NOT `test-approved`, NOT `DONE`, and
  NOT `CANCELLED`.
- An issue carrying the `plan` label is an orchestration artifact — never an
  executable work item. It is excluded exactly like `test-approved`/`DONE`/
  `CANCELLED`, on the initial resolve and on every re-resolve.
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

The batch plan is posted to GitHub, never to a file:

- **Multi-issue scope → Plan Issue.** Create a dedicated Plan Issue: title
  prefixed `PLAN:`, milestone `new`, type label `enhancement`, plus the `plan`
  label (the machine discriminator). It holds the parallel/sequential split,
  the ordered dependency chain, and the per-round score table. It is an
  orchestration artifact, not a work item. Closing a Plan Issue is human-only.
- **Single-issue scope → plan comment.** The plan comment on that issue
  suffices; no Plan Issue is created.
- **Promotion (single → multi).** The moment a re-resolve or an explicit user
  instruction grows the in-scope set beyond one issue, promote the run:
  create the Plan Issue right then, seed its body with the current plan state
  (ordered chain, split, link to the original work issue's plan comment, score
  table rows accumulated so far) and post a backlink comment on the original
  work issue ("run promoted, plan now tracked in #N"). A shrinking multi-issue
  run keeps its Plan Issue — history stays.
- **Dependency lines, both directions.** Every work issue's plan comment
  carries explicit `Depends on: #N` and `Blocks: #N` lines, consistent with
  the chain in the Plan Issue.
- **Amendments.** After every re-resolve that changes the in-scope set, post a
  plan amendment comment on the Plan Issue (added/removed issues, revised
  split, revised chain), update the `Depends on:` / `Blocks:` lines of every
  affected work issue with a new plan comment (never edit history away), and
  re-run the plan gate on the amendment. The score table in the Plan Issue
  gains one row per gate round, amendment rounds included.
- **Mirroring.** Every decision recorded in the Plan Issue that affects a work
  issue is mirrored to each affected work issue at decision time — a
  one-paragraph summary comment plus a backlink to the Plan Issue comment.
  The Plan Issue never substitutes for per-issue history.

---

## DONE — all of the following hold AND each has been demonstrated in this
conversation, because the evaluator reads only what you surfaced here:

1. For every in-scope issue, all open/ambiguous points (contracts, endpoints,
   payloads, states) are answered against the live API or the live system, the
   issue is updated with the verified facts (description or comment), and that
   change is committed.
2. The plan is posted where it belongs — single-issue run: plan comment on the
   issue; multi-issue run (at any point of its life): the Plan Issue exists and
   covers the final in-scope set including the parallel/sequential split and
   all amendments — and the latest plan-gate verdict is APPROVED
   (TOTAL >= 20, no dimension below 4).
3. Every deliverable named in the in-scope issues exists; you showed the tree.
4. The test suite runs and exits 0; you showed the output.
5. The implementation review verdict is APPROVED under the same rubric.
6. The acceptance criteria of each in-scope issue are demonstrated live in
   this conversation (run it, show the output) — not merely asserted.
7. The score table in the Plan Issue (or, single-issue run, in the work
   issue's comments) holds every round, `git status` is clean, and every
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
- When blocked or uncertain, ask Codex instead of stopping. Post question and
  answer as a comment on the affected issue (cross-cutting → the Plan Issue,
  mirrored per the BATCH PLANNING mirroring rule), take the answer as the
  decision, continue.
- If an issue is underspecified, do not guess silently: ask Codex, post the
  decision as a comment on that issue, and write the resulting interpretation
  back into the issue body.
- **Never expand the scope on your own.** If work on an in-scope issue reveals
  additional work, create a separate issue in milestone `new` instead of doing
  it — unless it is strictly required to satisfy the in-scope acceptance
  criteria.
- Every review verdict is posted verbatim as an Issue comment (naming the
  Judge used), and its scores land as a row in the score table — nothing is
  captured into files.
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
- If the same failure repeats three times, stop retrying. Post the blocker as
  a comment on the affected issue, ask Codex for a different route, take it.

## TURN PROTOCOL

- End every turn with a per-issue table: issue ID, milestone at start of
  turn, milestone now, which of the seven DONE items hold, which do not, what
  you do next.
- Stop after 60 turns even if not done, and summarise the state per issue.

---

## NO SIDE-CAR ARTIFACTS

This command mandates no files of its own. Every record of the run — plan,
amendments, decisions, blockers, review verdicts, score table — lives in
GitHub Issues, as described above. The stamped block below applies without
carve-outs, and the `plan-doc-gate` hook enforces it at runtime with no
exceptions for this command (user decision of 2026-08-01, issue #152).

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
