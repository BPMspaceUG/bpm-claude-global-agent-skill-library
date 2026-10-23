---
name: c-bpm-sk-gogo
description: "Unattended overnight run: implements all ready, unblocked tickets of the current repo with an agent team and Codex reviews"
disable-model-invocation: true
argument-hint: "[spec issue number | label]"
---

Argument (optional scope restriction — a spec issue number or a label; empty
means all ready tickets): $ARGUMENTS

/goal Implement every ready, unblocked ticket on the issue tracker of the repo
this session is running in, and get each one approved by an independent
reviewer. This is an unattended run: every decision goes to Codex, never to a
human. You are the TEAM LEAD. You coordinate; teammates do all ticket work.

PREFLIGHT (run in this order; on any failure write the reason to
decisions/run-log.md in the repo if possible, print it, and stop):
1. The current directory is inside a git repo with a configured remote.
   Use the repo root as the working root for everything below.
2. The working tree is clean. If not, stop and leave it exactly as it is;
   never stash or discard my changes.
3. The Matt Pocock skills configuration for this repo exists (written by
   /setup-matt-pocock-skills): issue tracker, triage labels, docs location.
   If it is missing, stop and say: "Run /setup-matt-pocock-skills in this
   repo first." Use only the configured tracker and labels.
4. The issue tracker is reachable with the configured access (e.g. gh auth
   status for GitHub).
5. Codex is installed and authenticated: run "codex exec --help" once (flags
   differ between versions), then send one trivial read-only request through
   "codex exec"; it must return an answer. Record the working Codex command
   line in decisions/run-log.md.
6. Detect how this repo runs its tests (package scripts, Makefile, CI config,
   README). If it is unclear, ask Codex once and record the answer in
   decisions/qa.md. Use that command for every test run in this run.
7. Check whether agent teams are available in this session
   (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS enabled, interactive session). Log
   the result. If teams are not available, use subagents with exactly the
   same contract. Continue either way.

SETUP:
- Determine the repo's default branch at runtime; never assume its name.
  Create the run branch agent/run-<YYYYMMDD> from it in the repo root and
  check it out. Every lead commit (decisions/, reviews/RUBRIC.md) goes on the
  run branch; the repo root stays on it for the whole run.
- mkdir -p decisions reviews plans (in the repo root).
- If reviews/RUBRIC.md does not exist, ask Codex once to propose one with 5
  dimensions scored 1–5 suited to this repo, ending with the approval rule
  "APPROVED means TOTAL >= 20 and no dimension below 4". Save and commit it.
  If it exists but has no approval rule, append that one and commit. Use it
  unchanged for the whole run.
- Create decisions/state.md: a header line "lead turns: 0", then one row per
  ticket in scope with columns
  ticket | spec | blocked-by | status | teammate | branch | verdicts | note.
  This file is the single source of truth for the run.

CONTEXT DISCIPLINE FOR THE LEAD (most important rule):
- Your whole input is decisions/state.md plus teammate status blocks. Source
  code, diffs, test logs, plans and review texts stay unread by you;
  implementation, tests and Codex reviews run inside teammates. The only
  exception is the final verification in DONE.
- Re-read decisions/state.md at the start of every turn instead of relying on
  conversation memory.
- A teammate's report is its status block. Take the block and continue; when
  a teammate sends more, ignore the rest and request no details.

LOOP (one pass per lead turn, until DONE holds or the turn limit is reached):
1. Re-read decisions/state.md, increment "lead turns", commit.
2. Recompute the ready frontier (see SCOPE).
3. Spawn teammates for frontier tickets (see TEAM).
4. For each status block received: write it into the ticket's row, shut the
   teammate down, commit decisions/state.md.
5. APPROVED: merge the ticket branch (see BRANCHING), push the integration
   branch, open or update the spec's draft PR.
   BLOCKED: add the ticket and its blocker line to decisions/blockers.md.
6. End the turn with: which DONE items hold, which do not, what you do next.

SCOPE – what counts as "ready":
- Specs created with /to-spec and tickets created with /to-tickets that carry
  the "ready for agent" triage label as configured in this repo.
- If an argument was passed, only that spec (and its tickets) or that label.
- A ticket is workable only when all its blocking edges are closed or
  approved in this run. Work the ready frontier of the dependency graph.
- Spec and ticket text stay unchanged; you and teammates only append comments.
- If the ready set is empty, write that to decisions/run-log.md, report it,
  and stop.

BRANCHING:
- One integration branch per spec: agent/<spec-number>-<slug>, cut from the
  default branch. Tickets without a spec get agent/<ticket-number>-<slug>.
- Each ticket is worked in its own git worktree on its own branch
  agent/<spec-number>/<ticket-number>, cut from the current integration branch.
- Only the lead merges an approved ticket branch into its integration branch,
  one merge at a time, in a lead worktree of the integration branch. On a
  merge conflict, spawn a fresh teammate to resolve it on the ticket branch,
  rerun tests and get a Codex re-review, then merge.
- Never commit to or merge into the default branch. Never force-push.
- Push the run branch and every integration branch; one draft PR per
  integration branch, linking all tickets it covers.

TEAM:
- Spawn one fresh teammate per ticket on the ready frontier. Run at most 3
  teammates at the same time. Serialise tickets that touch the same modules
  (ask Codex if unsure). One ticket per teammate; shut it down after its
  report.
- Give each teammate only: ticket number, spec number, integration branch,
  its worktree path and branch, the test command and the Codex command line
  from preflight, the absolute paths of reviews/RUBRIC.md (repo root) and of
  the repo's glossary and ADRs if they exist, and the absolute path of
  TEAMMATE.md in this skill's base directory with the instruction: "Read
  TEAMMATE.md and follow it exactly; it is your contract."

DONE means all of the following hold AND each has been demonstrated in this
conversation via status blocks or short command output:
1. Every ticket in scope is APPROVED and merged into its integration branch,
   or BLOCKED and listed in decisions/blockers.md with the reason.
2. Every APPROVED ticket has an approved plan review and an approved
   implementation review; you showed the status blocks.
3. Final verification by the lead: on each integration branch, run the full
   test suite once; it exits 0. Show only the last 20 lines of output.
4. The run branch and every integration branch are pushed; every integration
   branch has a draft PR; you showed the links.
5. Every processed ticket has a status comment.
6. Every processed ticket has reviews/<ticket-number>-scores.md with every
   round; decisions/state.md and decisions/run-log.md are current; git status
   is clean on every branch; all worktrees are removed.

GENERAL RULES:
- When blocked or uncertain as lead, ask Codex. Append question and answer to
  decisions/qa.md and take the answer as the decision.
- Claim nothing you have not shown in this conversation.
- Stop when "lead turns" in decisions/state.md reaches 60, even if not done.
  Let running teammates finish their current ticket, then write a morning
  summary to decisions/run-log.md and print it: tickets done, tickets blocked
  (with reason), PR links, open questions for the human.
