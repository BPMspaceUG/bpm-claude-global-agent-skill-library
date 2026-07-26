# agent.md

Codex-specific deltas for this repository.

`CLAUDE.md` is the single description of what this repo is, how it is laid out,
and what its conventions are — **that content is not repeated here.** Read
`CLAUDE.md` first; this file only adds what the reviewing agent (Codex, acting
as Judge) needs and what Claude Code does not.

Loaded by `my/commands/c-bpm-cm-openissues-team.md` (Phase 0d) alongside
`CLAUDE.md` and `SHARED_TASK_NOTES.md`. There is deliberately **no**
`gemini.md` or `vibe.md`: nothing loads them, so they would be duplication plus
drift — the failure this repo already hit in #114.

## Role

Codex is the **Judge**, not a producer. It reviews; it does not implement.

- Never invoked directly. `c-bpm-sk-devils-advocate` is the only sanctioned
  call site — it owns the live-Issue fetch, the sanitized invocation, and the
  descent down the substitute-Judge ladder.
- The ladder and every model-selection rule live in `c-bpm-sk-llm-selection`
  and nowhere else. Do not restate one here; a second copy goes stale the
  moment the policy moves (#119).
- No model version is pinned in this file, by design (#98).

## Review input

The payload is the **live Issue body plus comments**, fetched by the host shell
via `gh api` and piped on **stdin**.

- Never an authored `.md` side-car. Plans, progress and decisions live in the
  Issue; a file containing them is the violation `plan-doc-gate` blocks at
  runtime (#104, #105).
- The reviewer never needs to run `gh api` itself.
- Large inline argv hangs; stdin does not.

## Reviewing changes in this repo

Facts a reviewer needs that a producer already knows:

- **`dist/*.mjs` is what actually executes.** The matching `my/hooks/*.ts` is a
  hand-maintained mirror — there is no build step, no `package.json`, no `tsc`.
  A change to one without the other is drift, caught only by the checksum pin
  in `my/hooks/__tests__/*.fixtures.json`. That pin is a tripwire, not proof of
  behavioural equivalence: re-pinning both hashes passes regardless.
- **Hooks must exit 0 always.** The decision travels in stdout JSON, in both
  the nested `hookSpecificOutput` shape and the flat top-level mirror. A
  non-zero exit with empty stdout delivers no decision and fails **open**
  (#133).
- **Over-blocking is the expensive failure.** A gate on `Bash` or `Write` that
  denies ordinary repo work stops everything. Prefer explicit path and name
  rules over content or shape heuristics — the latter cost `issue-write-gate`
  four review rounds (#133, #136).
- **Tests are `bats` under `tests/bash/`.** Every suite must stay green, not
  only the one a change touches.

## Verdict boundaries

- A verdict is posted by the **Team Lead** as a GitHub Issue comment. A
  teammate that reports a verdict has fabricated one.
- `DONE` is human-only. No agent, reviewer included, ever sets it.
- No pull requests in this repo: one commit per issue, landed directly on
  `main` by the Lead.
