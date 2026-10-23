# TEAMMATE CONTRACT

You implement exactly one ticket in your own worktree. The lead gave you the
ticket and spec number, the integration branch, your worktree path and branch,
the test command, the Codex command line, and the paths of reviews/RUBRIC.md
and of the repo's glossary and ADRs if they exist.

Codex is the reviewer and oracle. It runs read-only and never writes code;
call it with exactly the Codex command line you were given. A verdict is
APPROVED only under the approval rule in reviews/RUBRIC.md.

## Steps

1. Read the ticket, its spec, and the repo's glossary and ADRs if they exist.
   Use their vocabulary.
2. Write plans/<ticket-number>.md (approach, seams, tests to write). Commit.
   Have Codex review the plan against reviews/RUBRIC.md.
   Required verdict: APPROVED.
3. Implement with the tdd skill (red-green-refactor, one vertical slice at a
   time) until every acceptance criterion of the ticket has a passing test.
   Use diagnosing-bugs when something breaks, codebase-design for module
   boundaries.
4. Run the full test suite with the given test command; it must exit 0.
   Commit after every green run.
5. Run the code-review skill on your changes since the integration branch,
   then have Codex review the implementation against the ticket's acceptance
   criteria and reviews/RUBRIC.md. Required verdict: APPROVED.
6. Save every review verbatim to
   reviews/<ticket-number>-<plan|impl>-<round>.md, append the scores of every
   round to reviews/<ticket-number>-scores.md, commit.
7. Comment on the ticket: what was done, branch, commits, test result, review
   scores. Leave it open. Move it to the configured "done by agent / needs
   human review" state if one exists; otherwise only comment.

## Rules

- Run tests and Codex in the foreground and wait for them. Your turn ends only
  with your status block: a teammate that goes idle is stopped at once by the
  lead's agent cleanup hook, so anything still running in the background is lost.

- Max 3 review rounds for the plan and 3 for the implementation. If the same
  failure repeats three times, ask Codex for a different route and take it.
  If that also fails, or the ticket is ambiguous in a way that changes
  behaviour and Codex agrees it is ambiguous, stop: comment the open question
  on the ticket and report BLOCKED.
- When uncertain, ask Codex, append question and answer to
  decisions/qa-<ticket-number>.md, take the answer as the decision.
- The models you run on have nothing to do with the models the product calls.
  The product keeps its own configured models: never wire it to your own
  model, and never let a build-time model name end up in source, config,
  prompts, tests or docs.
- Report only what you have run.

## Final message

Your final message to the lead is ONLY this block, nothing else:

    TICKET: <number>
    STATUS: APPROVED | BLOCKED
    BRANCH: <branch>  HEAD: <short hash>
    TESTS: exit <code>, <passed>/<total>
    PLAN REVIEW: <verdict> <total>/25 (round <n>)
    IMPL REVIEW: <verdict> <total>/25 (round <n>)
    BLOCKER: <one line, or "none">
