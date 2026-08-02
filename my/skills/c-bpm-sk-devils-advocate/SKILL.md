---
name: c-bpm-sk-devils-advocate
description: "Invoke the independent Judge — codex review, independent review, devil's advocate review, review gate, judge this issue, get a verdict, second pair of eyes. Canonical Judge invocation: live Issue fetch, sanitized sandboxed call, substitute-Judge ladder."
enforcement: block
intentPatterns: "codex review;;independent review;;devil'?s advocate review;;review gate;;judge (this )?issue"
user-invocable: true
argument-hint: "[issue number]"
allowed-tools: Read, Grep, Glob, Bash
---

# Devil's Advocate — Canonical Judge Invocation

This skill is the **only** place in the library that invokes the Judge. Every review
gate — plan approval, test design, implementation, audit, release — calls this skill
instead of running a review CLI itself. Model and ladder policy live in
`c-bpm-sk-llm-selection`; this skill is the operational half.

It fills the **Judge seat** of the Producer ↔ Judge review loop defined in
`c-bpm-sk-llm-selection` (loop mechanics, no cycle cap, guard rails — all defined
there, not restated here). The Producer never judges its own artifact.

## Live Issue Fetch (mandatory, first step)

**Fetch the live Issue body and comments via gh api BEFORE invoking the Judge.**
The payload is Issue-sourced: never an authored `.md`, never a side-car plan file,
never a summary retyped from memory.

```bash
OWNER=…; REPO=…; N=…          # discover OWNER/REPO from `git remote -v`
{ gh api repos/${OWNER}/${REPO}/issues/${N} --jq .body
  gh api repos/${OWNER}/${REPO}/issues/${N}/comments --jq '.[].body'
} > "${payload:=$(mktemp)}"
```

- Read the thread **at invocation time**. A thread that moved on since the last read
  invalidates the verdict; quote the timestamp of the newest comment you read.
- `gh issue view --comments` is unreliable (deprecated GraphQL path, can return
  empty) — use the two `gh api` calls above.
- **Judge unable.** If the fetch fails (auth, network, deleted Issue), the Judge is
  unable to review: descend the ladder below, and if no Judge can be reached, report
  **documented-blocked** on the Issue. Never emit a fabricated verdict, never guess
  what the Judge would have said, never let a gate pass on a missing review.

## Primary Judge — Codex

Codex is the primary Judge. Canonical invocation (from `c-bpm-sk-llm-selection`,
verbatim — sanitized non-login shell, network-enabled workspace sandbox, payload on
stdin):

```bash
env -u BASH_ENV -u ENV bash --noprofile --norc -c \
  'codex exec --skip-git-repo-check -s workspace-write -c sandbox_workspace_write.network_access=true 2>&1' \
  < "${payload}"
```

- The sanitizing tokens (`env -u BASH_ENV -u ENV`, `--noprofile`, `--norc`) and the
  token order are load-bearing — see issue #94 and #117 in `c-bpm-sk-llm-selection`.
- `-s workspace-write` with `sandbox_workspace_write.network_access=true` lets the
  Judge actually read the workspace and reach the network (issue #117).
  `danger-full-access` is never sanctioned — workspace-write is the ceiling.
- Ask for an explicit verdict scored against the **canonical review rubric in `c-bpm-sk-llm-selection`** (five dimensions, 1-5, with the PASS threshold defined there): `APPROVE` or `REJECT` with per-dimension scores and specific, actionable reasons. A verdict without scores and reasons is not a verdict — re-ask.

### Auth failure recovery (exactly once)

Auth-shaped failures only — `refresh_token_reused`, `token_expired`,
`401 Unauthorized`, "log out and sign in again":

```bash
cac pull --tool codex     # restores ~/.codex/auth.json
```

Then retry the invocation **once**. If the pull fails or the single retry still
returns 401, stop retrying (an older bundle can overwrite a good token) and descend
the ladder. Do not run this for transport, prompt, or sandbox failures.

## Substitute-Judge ladder

Ladder and family policy are defined in `c-bpm-sk-llm-selection`:
Codex → OpenRouter cheap frontier → Gemini → next available independent model.

- A substitute is a **substitute, not a co-Judge** — exactly one active Judge at a
  time, never a tiebreaker.
- **OpenRouter** is the first substitute tier. Use the OpenRouter MCP server if it
  is registered in the session; otherwise `curl` the API directly. Take
  `OPENROUTER_API_KEY` from the user-level `~/.env` — never a project-level `.env`.
  Resolve the newest slug of a sanctioned family from the live catalog
  (`/api/v1/models`) at invocation time; this skill names no model versions.
- The Issue payload is embedded in the request body for non-CLI Judges — same
  content, same live fetch.
- Record which Judge produced the verdict in the Issue comment. If every tier is
  unreachable: **documented-blocked**, gate does not pass.

## Rules

- MUST fetch the Issue live before every invocation — including re-reviews after a
  Producer revision.
- MUST post the verdict verbatim as an Issue comment, naming the Judge used.
- MUST NOT be invoked by the Producer to judge its own artifact.
- MUST NOT be wrapped in a login/rc shell (`bash -l`, `bash -lc`).
- MUST NOT pin a model version anywhere — `c-bpm-sk-llm-selection` resolves models.

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
