---
name: c-bpm-sk-llm-selection
description: "LLM selection and orchestration — choose model, assign agent, agent delegation, consensus finding, model selection, MCP discovery, task decomposition. Task-to-LLM matching, orchestration protocol, and conflict resolution."
enforcement: block
intentPatterns: "choose model;;assign agent;;agent delegation;;consensus finding;;task decomposition"
user-invocable: false
---

# LLM Selection & Codex Review Loop

How the Orchestrator selects and delegates tasks to available LLMs, and how the Producer ↔ Codex-as-Judge review loop runs until consensus.

## Available LLMs & Roles

| LLM | Role | Strengths | Use For |
|-----|------|-----------|---------|
| **Claude** | Orchestrator, Primary | Complex reasoning, planning, code review | Orchestration (required), complex tasks, quality-critical work |
| **Codex** | Implementer | Fast code generation, completions | Routine code tasks, quick completions, high-volume generation |
| **OpenRouter** | First substitute Judge (Codex unreachable only) | Cheap frontier families (GLM, DeepSeek, Kimi), independent of the Codex account | Substitute Judge in the review loop ONLY when Codex is unreachable — invoked through `c-bpm-sk-devils-advocate` |
| **Gemini** | Second substitute Judge (Codex and OpenRouter unreachable only) / Large-Context Reader | Large context, multimodal, alternate Judge when Codex is offline | Large document analysis, image processing, substitute Judge in the review loop ONLY when Codex is unreachable |

## Model Version Policy (single source — referenced everywhere)

This section is the single source of truth for model selection. No other skill or
command may name a concrete model version; they reference this section.

- **Codex (Judge / implementer):** invoke WITHOUT `-m`. Codex follows its own CLI
  default model. Never pin a Codex model version flag in any skill or command.
- **Claude roles (#112):** Fable is the default Producer and teammate model. Opus is used only where Fable is not a fit — long-horizon orchestration and deep multi-file reasoning. Codex stays the Judge; Producer and Judge are never the same model.
- **No `model:` key in frontmatter.** Skills and commands do not pin a model in their frontmatter; they inherit the session model and follow THIS section. Model policy is prose here, never a key there.
- **OpenRouter (first substitute-Judge tier):** when Codex is unreachable, the cheap frontier families on OpenRouter — GLM, DeepSeek, Kimi — take the Judge seat before Gemini. Resolve the newest slug at invocation time from the live catalog (`/api/v1/models`); never pin a numeric version. Never a co-Judge, tiebreaker, or third model in the Producer↔Codex loop.
- **`OPENROUTER_API_KEY` source:** the user-level `~/.env` exclusively — never a project-level `.env`, never a repo file, never inline in a skill or command.
- Every other skill and command references THIS section, never names a version.

## Rules

### Orchestrator Selection
- Orchestrator **MUST** always be Claude (newest model)
- Claude carries the primary workload
- Other LLMs assist but do not orchestrate

### Task Delegation
1. **Default to Claude** for complex, quality-critical, or ambiguous tasks
2. **Use Codex** for straightforward code generation when speed matters
3. **Use Gemini** for large-context or multimodal tasks, or as the substitute Judge in the Producer↔Codex review loop ONLY when Codex and OpenRouter are both unreachable (network outage, auth failure, binary missing). Never as a co-Judge alongside Codex. Never as a tiebreaker.
4. **Invoke the Judge only through `c-bpm-sk-devils-advocate`** — that skill owns the live-Issue fetch, the canonical sanitized command, and the substitute-Judge ladder. No other skill or command calls the Judge CLI itself.

## Codex Review Loop (Producer ↔ Judge)

This is the canonical review pattern for every artifact produced in this library
(plan, test design, implementation, audit report — anything an LLM authored).

**Roles**
- **Producer** — the LLM that authored the artifact (plan author, test designer,
  implementer, auditor). The Producer revises its own work when the Judge rejects.
- **Judge** — Codex acts as the LLM-as-a-Judge. The Judge is a single role filled
  by exactly one model at a time.

**Loop**

```
1. Producer submits artifact to the Judge.
2. Judge reviews and either APPROVES or REJECTS with specific reasons.
3. If APPROVED → done; the artifact moves forward.
4. If REJECTED → the artifact returns to the Producer. The Producer revises and
   re-submits to the Judge. Go to step 2.
5. The loop runs until both Producer and Judge agree (consensus). There is no
   cycle cap. There is no abandonment without consensus.
```

**Hard rules (KISS)**

- **No cycle cap.** The loop runs until consensus. "Max N cycles", "cap at N",
  "after N revisions" are forbidden — they were never requested by the user and
  were fabricated by an earlier session (see issue #89). Do not reintroduce them
  in this skill or any downstream artifact.
- **No user inside the loop.** The user is not a fallback Judge. The Judge does
  not "escalate to the user" when the loop runs long. The user is invoked only
  by explicit human direction outside the loop.
- **No third model for tiebreaking.** Convergence happens in practice; do not
  build infrastructure for the deadlock case.
- **Producer revises its own work.** Rejected artifacts go back to whoever
  produced them, not to a different model and not to the user.

**Non-Codex Judge — guard rails**

The fallback chain (Codex → OpenRouter cheap frontier → Gemini → next available independent model) exists
ONLY for the case where Codex itself cannot be reached. The following rules are
absolute and must not be relaxed:

- **Substitute, not co-Judge.** Gemini (or any non-Codex Judge) is invoked ONLY
  when Codex is unreachable — network outage, auth failure, binary missing,
  service down. It substitutes for Codex in the Judge role; it is never run
  alongside Codex as a second opinion or co-reviewer.
- **One Judge at a time.** The fallback chain runs sequentially: try Codex; if
  Codex is unreachable, try OpenRouter (cheap frontier); if OpenRouter is
  unreachable, try Gemini; if Gemini is unreachable, try the next available
  independent model. At any given step there is exactly one active
  Judge. Never two Judges concurrently.
- **Never a tiebreaker.** A non-Codex Judge is NEVER invoked to break a deadlock
  between Producer and Codex. If Codex is reachable and rejects, the Producer
  revises and re-submits to Codex — Gemini (or any other model) is not called
  as a tiebreaker, arbiter, mediator, or second opinion. The same rule applies
  in reverse if Gemini is the active Judge: Codex is not called to break a tie
  with Gemini.

This pattern is referenced by `c-bpm-sk-skill-creator`, `c-bpm-sk-skill-optimizer`,
`c-bpm-cm-openissues-team`, and every other skill or command that runs a Codex
review gate. It is the canonical definition; downstream skills must remain
consistent with it.

## Review Rubric (canonical)

Every Judge verdict scores the artifact on **five fixed dimensions, scored 1-5 each** (25 max). The dimensions are constant across every gate — plan, test design, implementation, audit; each gate states in its own prompt what each dimension means for that artifact.

1. **Correctness** — the artifact does what it claims; its reasoning and logic are sound.
2. **Completeness** — every required part is present: test coverage, edge cases, and all acceptance criteria addressed.
3. **Scope discipline** — confined to the intended files/contract; no unrelated change.
4. **Risk & safety** — failure modes assessed, the fail-closed direction chosen, rollback present.
5. **Evidence** — claims are verified by actually running or reading, not asserted.

**PASS threshold:** `TOTAL >= 20` **and** no dimension below 4 (every dimension >= 4). Below either bound is a FAIL, and the artifact returns to the Producer.

This threshold is the loop's **convergence criterion — a PASS threshold, never a cycle cap** (#89). The loop still runs uncapped (see the Hard rules above); it ends when the artifact clears the threshold on merit, not after any count of rounds.

**Referenced, never restated.** This is the single canonical definition. Any command or skill that runs a scored gate — `c-bpm-cm-goal-openissue`, `c-bpm-cm-openissues-team`, and downstream — cites this section by name; it does not re-list the dimensions or the numbers.

### Convergence & blocking policy

The adversarial stance stays on at **every gate round**, not only the first. A neutral Judge that relaxed after the opening pass would ship real defects: on the 2026-07-26 run the hook suite was green while `sudo bash -lc` still returned allow, and only the sustained adversarial stance caught it (#137). What changes across rounds is not the stance but the **blocking bar**, and the rubric threshold sets it:

- **Below threshold** — any dimension below 4, or TOTAL under 20: findings are blocking. The gate does not pass; the Producer revises and resubmits.
- **At or above threshold** — the gate PASSES. Any remaining findings are **residual-acceptable**: they do not hold the gate, they are filed as their own issues (findings-to-issues rule), and they never restart the loop.

This threshold is the loop's **convergence criterion** and the principled replacement for the fabricated cycle cap (#89): the loop stays **uncapped** — there is no fixed number of rounds — and it ends on merit when the artifact clears the rubric, never on a count. Every scored gate (plan, test design, implementation, audit) applies this one policy: it never passes on a bare defect list, and never blocks on a residual-acceptable nit.

## Codex Invocation (shell hygiene)

This is the canonical shell form for invoking the Codex Judge. Since #113 it lives
in exactly two places — this section (the policy) and `c-bpm-sk-devils-advocate`
(the operational skill that every gate calls). No other skill or command carries an
inline invocation; they delegate to `c-bpm-sk-devils-advocate` instead.

**Problem it solves (issue #94):** Codex's captured output must contain *only*
Codex's verdict. When `codex exec` is run from a login/rc-sourcing shell, the
profile/rc side-effects — `keychain`, `ssh-agent`, `curl` to raw.githubusercontent.com,
etc. — are emitted into the captured output. Codex then misreads that startup
chatter as file content under review and returns false-positive rejections
(observed: three fabricated review failures in a single session). Because
Codex's own internal shells inherit the parent environment, the fix is to clear
`BASH_ENV`/`ENV` and disable profile/rc in the invoking shell so nothing
downstream re-sources them.

**Canonical form** — sanitized, non-login shell, network-enabled workspace
sandbox, Issue-sourced prompt on stdin:

```bash
# #162: the Judge runs inside a throwaway detached worktree so it cannot write the
# canonical tree; a pre/post tree-integrity check on the canonical tree is the mandatory backstop.
payload="$(mktemp)"
{ gh api repos/${OWNER}/${REPO}/issues/${N} --jq .body
  gh api repos/${OWNER}/${REPO}/issues/${N}/comments --jq '.[].body'
} > "$payload"
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

**Rules**

- **Sanitize the environment.** `env -u BASH_ENV -u ENV` strips the variables
  that cause non-interactive shells (including Codex's own) to source rc files.
- **No login/rc shell.** `bash --noprofile --norc` — never `bash -l`, `bash -lc`,
  or any shell that sources `~/.bash_profile` / `~/.bashrc` / `~/.profile`.
- **Sandbox with network (issue #117).** `-s workspace-write` plus
  `-c sandbox_workspace_write.network_access=true` — the read-only default sandbox
  makes the Judge unable to read the workspace or reach the network, which it
  reports as an inability to review. `danger-full-access` is never sanctioned;
  workspace-write is the ceiling.
- **Reviewer cannot write the canonical tree (#162).** `workspace-write` is required — the Judge must run `bats`, and on codex-cli 0.143.0 the `read-only` sandbox blocks `/tmp`, so the suite cannot run there. It is therefore confined to a throwaway detached `git worktree`, discarded after review, so the Judge's writes never reach the canonical tree. A mandatory pre/post `git status --porcelain` snapshot reverts (`git checkout -- .` + `git clean -fdq`) and fails the gate loud (`TREE MUTATED`) on any canonical-tree delta.
- **Token order is load-bearing.** `codex exec --skip-git-repo-check` stays
  contiguous and the sandbox flags follow it, so the guard suites keep matching.
- **Prompt on stdin, Issue-sourced.** Pipe the Issue body and its comments in on
  stdin — never a large inline argv (it hangs), and never an authored `.md`.
- **Inner-shell pollution only — the stream is NOT guaranteed clean.** This form
  removes profile/rc output from the shell it starts, and nothing more. Startup
  noise from the **outer launcher/sandbox shell** (`keychain: cannot create …
  Read-only file system`, `curl: (6) Could not resolve host: …`) is emitted
  *before* this form takes effect and is **not** suppressed by it — no invocation
  flag can reach that layer. Verified: `env -u BASH_ENV -u ENV bash --noprofile
  --norc -c 'printf "INNER_OK\n"'` still shows the banners ahead of `INNER_OK`,
  while the inner shell itself contributes zero noise lines.
- **Never treat the first lines of output as the verdict.** Locate the verdict by
  its marker (`APPROVE` / `REJECT`) and parse from there. Reading from the top of
  the stream is how wrapper noise gets mistaken for review content — the exact
  false-positive failure #94 exists to prevent.

> The only cure for the *outer* layer is guarding `keychain` to interactive shells
> in the host's rc — on this host the culprit is an unguarded `eval $(keychain …)`
> at `~/.bashrc:2` (a `bpm-<host>` dotfiles concern, tracked in **issue #130**). This
> invocation is the library-side mitigation for the *inner* shell, which it fixes
> regardless of host dotfile state; it cannot fix the outer one.

## LLM Availability Handoff

```
## LLM Availability Handoff
- Claude: Available (orchestrator)
- Codex: Available
- Gemini: Available / Not available
```

## Orchestration Protocol

### MCP Discovery

At planning start, discover all MCP servers in the current session:
1. Determine which servers are relevant to the current objective
2. Publish **MCP Availability Handoff** before delegating tasks

### MCP Availability Handoff

```
## MCP Availability Handoff
- Server A: Available (relevant)
- Server B: Available (not relevant to current task)
- Server C: Not available
```

### Task Decomposition

Translate user goals into a structured task plan:
1. Sequenced task list with acceptance criteria per task
2. Agent/LLM assignment per task (using delegation rules above)
3. Scope boundaries — no overlapping or conflicting tasks
4. Assumptions block — versions, environment, dependencies
5. Expected completion order
6. Follow `c-bpm-sk-milestone-type` for issue lifecycle and type enforcement when creating or tracking issues

All implementers MUST rely on Orchestrator handoffs and may not probe MCP servers independently.

## Success Criteria

- No LLM used outside its designated role
- Conflicts resolved efficiently through consensus
- Claude handles orchestration and complex tasks
- Efficient workflow without sacrificing quality

## Common Failure Modes

- Using secondary LLM for orchestration
- Over-delegating complex tasks to Codex for speed
- Skipping the Codex Judge review at a mandatory gate
- Imposing an artificial cycle cap on the Producer ↔ Codex loop
- Escalating a Codex rejection to the user instead of returning the artifact to the Producer
- Inviting a third model alongside Codex to break a tie
- Running Gemini (or any non-Codex Judge) as a co-Judge or second opinion while Codex is reachable
- Not checking LLM availability before assignment

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
