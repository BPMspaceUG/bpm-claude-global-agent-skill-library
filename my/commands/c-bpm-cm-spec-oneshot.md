---
name: c-bpm-cm-spec-oneshot
description: "Create or version a one-shot specification and its overnight build prompt — spec oneshot, write the spec, new spec version, overnight build prompt, rebuild from empty directory. Produces /specification/<FAMILY>-<X.Y.Z>.md and /prompts/<FAMILY>-<X.Y.Z>__impl-…__rev-…__harness-claude.md in the current repo."
argument-hint: "[major|minor|patch] [--implementer <model>] [--reviewer <model>] [-- author notes]"
---

# /c-bpm-cm-spec-oneshot — Create or version a one-shot specification and its overnight build prompt

> Command text for Rob's global skill library `BPMspaceUG/bpm-claude-global-agent-skill-library` (item `c-bpm-cm-spec-oneshot`; user-invokable as `/c-bpm-cm-spec-oneshot`; installed per machine, used in any repo).
> Maintenance: when a build's `RETRO.md` or a spec review finds a recurring gap in this command itself (not in the project), file it as an issue in the library repo — never patch the command inside a project repo.
> Repo-agnostic: it never contains domain knowledge. The domain comes from the repo it is run in.
> Arguments (all optional): `major | minor | patch` to force the version bump; `--implementer <model>` and `--reviewer <model>` for the prompt file name; free text after `--` as author notes for this version.

Arguments passed by the user: $ARGUMENTS

---

## Purpose

Produce, in the current repository, a **self-contained specification** under `/specification/` from which an autonomous agent can rebuild the **entire project from an empty directory overnight**, without Rob or any other human being asked anything, and a **build prompt** under `/prompts/` that invokes that specification with `/goal` and runs until done or until its turn budget is exhausted. Every run of this command produces a **new spec version** (SemVer): `1.0.0` if no spec exists, otherwise the next version. Old versions are never edited.

The bar for the spec: a capable engineer who has never seen this repo, with no access to its git history, Slack, issues or Rob, must be able to rebuild the project to the same behaviour **using the spec alone**. Anything the builder would otherwise have to ask a human is either decided in the spec, or delegated by the spec to Codex (the oracle) with an explicit decision rule.

## Roles

- **You** (this session) are the spec author. You read, you decide, you write. You do not implement.
- **Codex** is the read-only reviewer of the spec: `codex exec --skip-git-repo-check --sandbox read-only "REQUEST"` (run `codex exec --help` once first; flags differ between versions). Codex never writes.
- **Rob** is available in this session only for the questions in step 4 — at most one short grilling round. Everything else you decide yourself and record as a decision in the spec.

Use Matt Pocock's skills (and only those): `domain-modeling` for every term, `grilling` for the single human round, `research` for facts outside the repo, `to-spec` as the writing discipline, `code-review`'s two axes (standards, spec) as the frame for the acceptance criteria, `codebase-design` to describe the architecture. Do not reference Superpowers skills.

Language: everything you write is in **English**, regardless of the conversation language. Spelling conventions from the repo's `CLAUDE.md`/`GLOSSARY.md` win.

---

## Step 0 — Preconditions (print a short check table, stop on a blocking miss)

| Check | How | Blocking |
|---|---|---|
| Inside a git repo with a clean or committed working tree | `git status --porcelain` — if dirty, commit or stash first, with Rob's one-word OK | yes |
| Pocock skills present (`to-spec`, `domain-modeling`, `grilling`, `research`, `codebase-design`) | skill listing | yes |
| Pocock skills model-callable in this session (`to-spec`, `to-tickets`, `implement-spec`, `retro` appear in your own skill list, not only as user commands) | your skill listing, and `~/.claude/hooks/c-bpm-hk-skills-refresh.sh check` shows `locked skills` = 0 | yes — if locked: run `~/.claude/hooks/c-bpm-hk-skills-refresh.sh unlock`, then stop and tell Rob to restart Claude Code |

This step never runs the plugin update or `c-bpm-cm-library-pull` itself: the SessionStart hook `c-bpm-hk-skills-refresh` keeps both current, and changes only take effect after a restart. If `check` shows an upstream version newer than the installed one, say so in the check table and continue.
| `codex` CLI present | `codex --version`, `codex exec --help` | no — note it; the spec review in step 6 then falls back to a self-review and the build prompt keeps the Codex lines for the build machine |
| `gh` authenticated (only needed to read open issues) | `gh auth status` | no |
| Repo standing docs | `CLAUDE.md`, `AGENTS.md`, `GLOSSARY.md`/`GLOSSARY-MAP.md`, ADRs, `README.md` — read them fully | — |

---

## Step 1 — Discover the current state

1. **Existing specs**: list `/specification/*.md` (also accept `spec/`, `specs/`, root `SPEC*.md` if that is what the repo uses — then keep the repo's folder and say so). Parse versions from file names of the form `<FAMILY>-<MAJOR>.<MINOR>.<PATCH>.md`. Identify the latest version and its status line. If none: this run creates `1.0.0` and the family name is derived from the repo name unless `CLAUDE.md` names one.
2. **What changed since the last spec**: `git log --stat <last-spec-commit>..HEAD`, closed issues/PRs since then (`gh issue list --state closed --search "closed:>=<date>"`), new or changed tests, new config keys, new dependencies, new entries in `GLOSSARY.md` and ADRs, any `decisions/` or `reviews/` folders from previous overnight runs (`build-*/**/decisions/qa.md` is gold: every question an implementer had to ask Codex is a hole in the previous spec — each one becomes a decided item in this version).
3. **Previous build prompts**: `/prompts/*.md` — reuse their structure and run-naming scheme; never change the scheme without a reason recorded in the spec changelog.
4. **The actual system**: read the code, tests, schemas, migrations, configs, CI, Dockerfiles, Makefiles, UI, docs. Build a mental model good enough to write the architecture, data model, interfaces and behaviours **from the code as it is**, not from what the README claims. Where code and README disagree, the code wins and the discrepancy goes into the changelog as "clarified".
5. **Decide the version bump** (unless forced by argument): MAJOR if the rebuilt system would be incompatible with the previous spec's data, APIs or file conventions; MINOR if new behaviour was added; PATCH if only clarifications, corrections or decided-questions. Print the decision with a one-line reason.

---

## Step 2 — Model the domain before writing

Run `domain-modeling` over the repo: every noun in the spec must be a term from `GLOSSARY.md` or get added there in this session (commit the glossary change separately). Avoided synonyms are listed. If the repo has no `GLOSSARY.md`, create it now (the Pocock convention since plugin 1.3.0) and tell Rob where it lives.

---

## Step 3 — Write the specification `/specification/<FAMILY>-<X.Y.Z>.md`

Fixed skeleton. Every section is mandatory; "not applicable" is a valid content, "TBD" is not. Sections 11 and 13 are what make the overnight run possible — write them last and with the most care.

1. **Header** — family, version, date, status (`DRAFT` until step 6 passes, then `APPROVED <date>` with the review link), supersedes `<previous version>`, author notes from the argument.
2. **Changelog vs. previous version** — added / changed / removed / clarified / decided (every previous `decisions/qa.md` question that is now answered in the spec is listed here with its answer). For `1.0.0`: "initial".
3. **Purpose and scope** — what the system is, for whom, the business outcome, the boundaries. One paragraph, then bullets.
4. **Non-goals** — explicit, so the builder does not "improve" things.
5. **Vocabulary** — the glossary terms used, each with its one-line definition (copy from `GLOSSARY.md`, keep in sync).
6. **Domain model** — entities, attributes (name, type, mandatory, allowed values, defaults, invariants), relationships with cardinalities, state machines with allowed transitions and who may trigger them.
7. **Architecture** — components, boundaries, runtime topology, tech stack with **exact versions** (language, framework, DB, build tool, package manager), directory layout of the deliverable, configuration surface (every env var / config key, type, default, secret or not). Any model, API, service or vendor the **product** calls is a config value with a default; it is never a build-time constant, and build-time model names never appear in the product.
8. **Interfaces** — every external interface the system offers or consumes: HTTP/CLI/file/queue contracts with request/response shapes, error codes, auth, versioning; UI: screens, flows, states, validation, copy of the key labels; integrations: which endpoint, which auth, rate limits, sandbox vs live.
9. **Behaviours** — the functional rules as numbered, testable statements ("B-12: when X and Y, the system does Z"), grouped by domain area; include edge cases, concurrency, idempotency, timezones, money/rounding, i18n where they apply.
10. **Quality attributes** — performance budgets, limits, security requirements (authz model, input validation, secrets handling), observability (logs, metrics, health endpoint), accessibility, browser/OS targets. Numbers, not adjectives.
11. **Decisions made for the builder** — the list of everything that was ambiguous in the repo or in previous runs, with the decision taken and a one-line rationale. This is where previous `decisions/qa.md` content lands. The goal is that an implementer never needs a human; if a decision is reversible and low-stakes, decide it here rather than leaving it open.
12. **Decision policy for the unforeseen** — the rule the builder follows when the spec is silent: (a) if a sensible default exists and is reversible, take it, log it in `decisions/qa.md`, continue; (b) otherwise ask Codex with a question that contains the relevant spec sections and the options, take Codex's answer as the decision, log question and answer, continue; (c) never stop, never ask a human; (d) if the same failure repeats three times, write `decisions/blockers.md`, ask Codex for a different route, take it.
13. **Validation and test suite** — exactly what the builder must deliver as tests: unit, integration, contract, end-to-end, fixture data; the single command that runs them (`make test`, `npm test`, `pytest` …) and what exit 0 means; coverage or invariants that must hold; smoke test for the running system.
14. **Deliverables** — the complete file tree of the finished build (every file or directory the reviewer will look for), including `README.md`, `.env.example`, CI config, a `STATE.md`/footer that names spec version, implementer and reviewer **only** in run metadata.
15. **Acceptance criteria** — numbered, each one demonstrable in a transcript by a command and its visible output. These map 1:1 onto the DONE items of the build prompt.
16. **Open contract questions** — facts about external systems the builder must verify against the live tool or API before building (current API shapes, plugin syntax, versions), with the instruction to rewrite this section with the verified facts and commit it inside the run directory.
17. **Review rubric** — the dimensions (default five: spec compliance, correctness as shown by tests, code quality & standards, completeness of deliverables, operability/docs), 1–5 each, approval threshold `TOTAL >= 20` and no dimension below 4, unless the repo's `CLAUDE.md` defines another.
18. **References** — repo paths, docs, external standards, previous spec version.

Writing rules: no prose where a table or a numbered list is more precise; no "should" — use "must" / "must not" / "may"; every number has a unit; every example is complete and runnable; link, do not paste, licensed third-party text; keep the spec in one file (append-only growth is fine; the reference specs morphcook `SPEC.md` and hogwarts `prompt.txt` are single files on purpose).

---

## Step 4 — The one human round (optional, max. one)

Only if, after step 3, there is a decision that is **product-defining, hard to reverse, and not inferable from the repo** (e.g. two incompatible directions the code is currently torn between), run one `grilling` round with Rob, breadth-first, all such questions at once, each with your recommended default. Rob's answers go into section 11. If he does not answer a question, the recommended default is taken and marked "default taken, not confirmed". Everything else: decide yourself, never ask.

---

## Step 5 — Write the build prompt `/prompts/<FAMILY>-<X.Y.Z>__impl-<IMPLEMENTER>__rev-<REVIEWER>__harness-claude.md`

Defaults for the placeholders: `<IMPLEMENTER>` = the model this session runs on, as named by Rob or `unknown-implementer`; `<REVIEWER>` = `codex` (the model Codex is configured with on the build machine). Rob renames the file per run; the content below is model-agnostic.

```
/goal Build the entire project specified in <SPEC_FILE_PATH> inside <RUN_DIR> from an empty directory and get it approved by an independent reviewer.

RUN IDENTITY (do not change): spec=<FAMILY>-<X.Y.Z> implementer=<IMPLEMENTER> reviewer=<REVIEWER> harness=claude-code

FIRST, before anything else:
  mkdir -p <RUN_DIR>/decisions <RUN_DIR>/reviews <RUN_DIR>/tickets
  cp <SPEC_FILE_PATH> <RUN_DIR>/SPEC.md
  cd <RUN_DIR> && git init (if the repo policy is one git repo per build) — otherwise work on a branch build/<run-id>.
  All work happens inside <RUN_DIR>. Never modify anything outside it: not /specification, not /prompts, not other build directories, not the repo root.

DONE means all of the following hold AND each has been demonstrated in this conversation, because the evaluator reads only what you surfaced here:
1. The "Open contract questions" in <RUN_DIR>/SPEC.md are answered against the live tools/APIs, the section is rewritten with the verified facts, and that change is committed.
2. <RUN_DIR>/PLAN.md exists (the ticket graph from /to-tickets, ordered, with dependencies) and its review verdict is APPROVED (TOTAL >= <THRESHOLD_TOTAL>, no dimension below <THRESHOLD_MIN>, rubric = SPEC.md section "Review rubric").
3. Every deliverable in SPEC.md section "Deliverables" exists; you showed the tree.
4. The test suite defined in SPEC.md section "Validation and test suite" runs and exits 0; you showed the full output.
5. The implementation review verdict is APPROVED under the same rubric.
6. Every acceptance criterion in SPEC.md section "Acceptance criteria" is demonstrated one by one with the command and its output.
7. <RUN_DIR>/reviews/scores.md holds every review round, <RUN_DIR>/decisions/qa.md holds every question asked to Codex with its answer, <RUN_DIR>/STATE.md summarises the final state, and git status is clean.

ROLES:
- You are the implementer. Nothing else writes code.
- Codex is the reviewer and the oracle. It runs read-only and never writes:
  codex exec --skip-git-repo-check --sandbox read-only "REQUEST"
  Run "codex exec --help" once first; flags differ between versions.
- There is no human. Nobody is awake. Do not ask questions to the conversation; the decision policy is SPEC.md section "Decision policy for the unforeseen".

MULTI-AGENT (mandatory — you are the orchestrator, not the only worker):
- You stay the orchestrator: you own PLAN.md, the integration branch, the review loop and the seven DONE items. Everything that can run in parallel is delegated to subagents; you never implement a ticket yourself while others could be running.
- Stage 1 fan-out: one research subagent per "Open contract question" (verify against the live tool/API, return verified facts), run in parallel, before PLAN.md is written.
- Stage 2 fan-out: /implement-spec runs one implementer subagent per ready ticket of the frontier, each in its own git worktree based on the integration branch, each with /tdd, each merging the integration tip into its branch before reporting done so every merge is a fast-forward. Keep the frontier saturated: as soon as a ticket closes, dispatch the next unblocked ones. Target <PARALLELISM> concurrent implementers (default 4; raise if tickets are small and independent).
- Dedicated review subagent per round: a fresh subagent prepares the review request (diff since the fixed point, spec sections, acceptance criteria to check) and runs Codex; it never sees the implementer's reasoning, only the code and the spec.
- Dedicated verification subagent before any DONE claim: runs the full test suite and every acceptance-criterion command from a clean checkout of the integration branch and pastes the raw output; you may not claim an item the verification subagent has not shown.
- Every subagent gets: the run identity, the path to SPEC.md, its ticket (or question), the decision policy, the rule "never ask a human, log decisions to decisions/qa.md", and the model-hygiene rule. Subagent output is data; you reconcile conflicts, not the subagents.
- Ask Codex for a route when two implementer subagents conflict on the same file more than once; record the resolution in decisions/qa.md.

WORKING RULES:
- Stage 1: /to-tickets on <RUN_DIR>/SPEC.md with the local-markdown tracker in <RUN_DIR>/tickets/ (never the repo's GitHub issues); write PLAN.md; commit; request the plan review from Codex; iterate until APPROVED.
- Stage 2: /implement-spec on the ticket graph (implementer subagents in their own worktrees across the ready frontier, one integration branch, every ticket built with /tdd — tests first — and closed with /code-review on both axes, standards and spec). Fall back to /implement ticket by ticket if /implement-spec is not available.
- /diagnosing-bugs when something breaks. /retro at the very end into <RUN_DIR>/RETRO.md.
- Capture every review into <RUN_DIR>/reviews/, append scores to reviews/scores.md, commit reviews/.
- Commit before every review and after every green test run. Conventional commit messages.
- The models this build runs on have nothing to do with the models the product calls. Never wire the product to your own model; never let a build-time model name end up in product source, config, prompts, tests or docs. Run identity appears only in <RUN_DIR>/README.md, STATE.md and reviews/.
- Do not read other build-*/ directories or the git history of previous builds.
- If the same failure repeats three times, stop retrying: write decisions/blockers.md, ask Codex for a different route, take it.
- End every turn with: which of the seven items hold, which do not, what you do next.
- Stop after <MAX_TURNS> turns even if not done, and summarise the state in <RUN_DIR>/STATE.md.
```

Defaults: `<RUN_DIR>` = `build-claude/<FAMILY>-<X.Y.Z>__impl-<IMPLEMENTER>__rev-<REVIEWER>/`, `<THRESHOLD_TOTAL>` = 20, `<THRESHOLD_MIN>` = 4, `<MAX_TURNS>` = 60, `<PARALLELISM>` = 4 — unless the repo's `CLAUDE.md` or a previous prompt says otherwise. Also write or update `/prompts/README.md`: naming scheme, how to instantiate, how the morning review works (`STATE.md`, `reviews/scores.md`, `decisions/qa.md`), and the rule that the first commit touching a run directory is the untouched one-shot output.

---

## Step 6 — Review the spec with Codex until it is one-shot-able

Ask Codex, read-only, with the whole spec attached:

> "You are to rebuild this project from an empty directory using only this specification, overnight, with no human. List every question you would have to ask a human before or during the build, every ambiguity, every missing number, every external fact you cannot verify, and every acceptance criterion you could not demonstrate with a command. Then score the spec on the rubric in its own 'Review rubric' section."

For every question Codex returns: answer it in the spec (section 11 if it is a decision, the relevant section if it is missing detail, section 16 if it is an external fact to verify at build time). Re-run the review. Stop when Codex returns **no human-blocking questions** and the score meets the threshold, or after 5 rounds — then record the remaining items in section 11 as "decided by default" with your default. Save each round as `/specification/reviews/<FAMILY>-<X.Y.Z>-round-<n>.md` and the scores in `/specification/reviews/scores.md`. Without `codex`, do the same review yourself in a fresh subagent and say so in the status line.

Set the status line to `APPROVED <date>` only after this step.

---

## Step 7 — Commit and report

- Commits, in this order: glossary changes; `/specification/<FAMILY>-<X.Y.Z>.md` (+ reviews); `/prompts/...` (+ README). Conventional messages: `docs(spec): <FAMILY> <X.Y.Z> — <one-line changelog>`, `docs(prompts): build prompt for <FAMILY> <X.Y.Z>`.
- Never delete or edit a previous spec version; if the previous version's status line should say "superseded by X.Y.Z", add that one line and nothing else.
- Report to Rob, in his language, in this order: version and bump reason; changelog gist; the decisions you took alone (section 11, as a short list); what Rob confirmed in the human round (if any); the Codex review score and remaining defaults; the exact prompt file path and the one command to start the overnight run (`cd <repo> && claude` then paste the prompt). No advice beyond that.

---

## What this command never does

- It never implements, refactors or "cleans up" the repo.
- It never puts domain knowledge, model names or project specifics into itself; those live in the repo and the spec.
- It never leaves a `TBD`, a "should", or an acceptance criterion without a demonstrating command in the spec.
- It never asks Rob more than one round, and never for anything the repo or a sensible default already answers.
