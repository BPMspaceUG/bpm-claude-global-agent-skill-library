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
JUDGE_WT="$(mktemp -d)"; git worktree add --quiet --detach "$JUDGE_WT" HEAD
BEFORE="$(git status --porcelain)"
( cd "$JUDGE_WT" && env -u BASH_ENV -u ENV bash --noprofile --norc -c \
    'codex exec --skip-git-repo-check -s workspace-write -c sandbox_workspace_write.network_access=true 2>&1' \
    < "$payload" )
if [ "$(git status --porcelain)" != "$BEFORE" ]; then
  git checkout -- .; git clean -fdq        # revert tracked + remove untracked the review added
  echo "TREE MUTATED mid-review — gate FAILS (#162)"
fi
git worktree remove --force "$JUDGE_WT"
```

- The sanitizing tokens (`env -u BASH_ENV -u ENV`, `--noprofile`, `--norc`) and the
  token order are load-bearing — see issue #94 and #117 in `c-bpm-sk-llm-selection`.
- `-s workspace-write` with `sandbox_workspace_write.network_access=true` lets the
  Judge actually read the workspace and reach the network (issue #117).
  `danger-full-access` is never sanctioned — workspace-write is the ceiling.
- **Confined to a throwaway worktree (#162).** The Judge runs from `cd "$JUDGE_WT"` inside a detached `git worktree`, so its `workspace-write` sandbox root is the temp worktree, not the canonical tree; the worktree is removed after review. The pre/post `git status --porcelain` snapshot is the mandatory backstop — on any canonical-tree delta it reverts (`git checkout -- .` + `git clean -fdq`) and fails loud (`TREE MUTATED`).
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

## The Critic — adversarial stance, graded verdict

This skill combines two concerns the review literature keeps separate, because neither alone converges on a cheap model:

- **Judge** = *what comes out*: a graded verdict against the canonical rubric. Its failure mode is sycophancy — it nods everything through.
- **Devil's Advocate** = *the stance the model takes*: deliberately adversarial — find the real defect, do not rubber-stamp. Its failure mode is noise — it always finds something, even when there is nothing.

One role carries both — the **Critic**. Keep this one skill; do not split the two concerns into separate skills (the distinction is didactic). The adversarial stance keeps the verdict honest; the rubric threshold gives it a machine-evaluable stop signal.

### Verdict output contract — every invocation MUST return

1. **Per-dimension scores** (1-5) against the **canonical review rubric in `c-bpm-sk-llm-selection`**, their **TOTAL**, and an explicit **PASS** / **FAIL** against the threshold defined there. (The rubric numbers live only in #145 — never restated here.)
2. On FAIL, **each finding tagged `blocking` or `residual-acceptable`** — a real defect that should not hold the gate is residual-acceptable, not blocking. A defect list with no such tag is an **incomplete verdict** — re-ask.
3. Per finding, the **evidence the Critic actually verified** — what it ran or read ("verified against the live hook: DENY…"), never inferred from an indirect signal. A finding inferred rather than verified (e.g. read off `git status` without checking authorship, #135) is downgraded and must say so.

The stance stays adversarial by default — that is where the honest criticism comes from. The threshold, not any count of rounds, ends the loop (#89: convergence, not a cap); the loop-level policy is in `c-bpm-sk-llm-selection`.

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
