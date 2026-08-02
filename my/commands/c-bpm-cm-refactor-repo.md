---
name: c-bpm-cm-refactor-repo
description: "Refactor this repo — refactor, code cleanup, restructure, reorganize codebase. Spawns 2-6 agent teammates for parallel refactoring. Codex-reviewed, test-mandatory, milestone-tracked."
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Glob, Grep, LS, Task, Teammate, SendMessage
---

# /refactor_repo — Agent Team Refactoring

You are the TEAM LEAD. You run in DELEGATE MODE.
- Switch to delegate mode immediately (Shift+Tab if not already active)
- You implement NOTHING yourself — you coordinate, review, and approve ONLY
- You do NOT write code, do NOT edit files, do NOT run tests yourself
- Your tools are: spawning teammates, messaging, managing tasks, running Codex reviews, managing GitHub Issues/Milestones via MCP
- **Read `c-bpm-sk-milestone-type` skill** for milestone lifecycle definitions, transition rules, and Codex gate patterns. Use the FULL lifecycle and create all milestones in Phase 0.
- If you catch yourself about to edit a file or write code: STOP — delegate it to a teammate instead

Start immediately with Phase 0 and run through to Phase 8 without stopping. The
TEAM LEAD **never asks the user** for confirmation and **never waits for user
confirmation** at any gate. The Judge — invoked via `c-bpm-sk-devils-advocate` —
is the gate authority; the operator is not in the loop.

$ARGUMENTS

---

## GITHUB ISSUE TRACKING — CORE RULES

### Issue Types
Use GitHub Issue Types ONLY:
- **BUG** — for existing problems, vulnerabilities, broken behavior, code smells
- **FEATURE** — for improvements, new functionality, refactoring enhancements, new tests, documentation

Do NOT use labels. Do NOT use tags. Issue Type + Milestone is the only tracking mechanism.

### One Issue Per Improvement
- Each improvement = exactly ONE issue
- ALL phases (plan, test design, implementation, review, approval) are documented as COMMENTS within that issue
- Use sub-issues only if genuinely needed for independent sub-tasks
- NEVER create multiple issues for the same improvement

### Milestone-Based Lifecycle
**Read `c-bpm-sk-milestone-type` skill for full milestone definitions, rules, and Codex gate patterns.**

Uses the FULL lifecycle: `new` -> `planned` -> `plan-approved` -> `test-designed` -> `test-design-approved` -> `implemented` -> `tested-success`/`tested-failed` -> `test-approved` -> `DONE` (human only). Abort: any state except `DONE` may move to `CANCELLED` (human-only, terminal).

### Existing Issues
Before creating ANY new issues:
- Read ALL open issues — they may already describe problems the refactoring should address
- Read ALL closed issues (recent) — they contain context and past decisions
- If an existing open issue matches a discovered improvement: USE that issue, assign the correct milestone, add a comment linking it to this refactoring
- If someone already filed a feature request or bug: incorporate it, don't duplicate
- Reference related closed issues in comments for context

---

## PHASE 0 — DISCOVERY & ENVIRONMENT SCAN

### 0a. Create Milestones
Using GitHub MCP, create ALL lifecycle milestones upfront (skip any that already exist):
1. `new`
2. `planned`
3. `plan-approved`
4. `test-designed`
5. `test-design-approved`
6. `implemented`
7. `tested-success`
8. `tested-failed`
9. `test-approved`
10. `DONE`
11. `CANCELLED`

### 0b. MCP Servers
Check which MCP servers are connected:
- `/mcp` command to list connected servers
- `.claude/settings.json` for configured servers
- `.mcp.json` or `.mcp/` in the project root

GitHub MCP is REQUIRED. If not available: STOP and tell the user to connect a GitHub MCP server.

For each other discovered MCP server: note capabilities and relevance.

### 0c. Existing Skills
- Check `.claude/skills/` in the project
- Check `~/.claude/skills/` for user-level
- Check for plugins: `.claude/plugins/` or via `/plugins`

If a specialized skill exists (e.g. appsec-threatlite, test-harness): assign it to the relevant teammate.

### 0d. Project Context
- Read `CLAUDE.md`, `.claude/settings.json`, project-level config
- Check CI/CD configuration (.github/workflows/, .gitlab-ci.yml, etc.)
- Note coding conventions, linting rules, test frameworks

### 0e. Existing GitHub Issues
Using GitHub MCP:
- Fetch ALL open issues — which relate to potential refactoring?
- Fetch recently closed issues — relevant context?
- Feature requests the refactoring could address?
- Bug reports caused by code quality issues?

Output a discovery report listing all found resources.

---

## PHASE 1 — REPO SYNC & SECURITY

1. `git pull --rebase` — fetch newest version
2. `git log --oneline -10` — understand recent changes
3. Check open PRs for in-flight work that might conflict
4. Security scan:
   - Hardcoded secrets: `grep -rn "password\|secret\|api_key\|token\|private_key" --include="*.{py,js,ts,php,rb,go,java,env,yml,yaml,json,cfg,ini,toml}" .`
   - Dependency audit: package.json → `npm audit`; requirements.txt → `pip audit`; composer.json → `composer audit`; Gemfile → `bundle audit`; go.mod → `govulncheck ./...`
   - .gitignore check: .env, credentials, keys must be ignored
   - File permissions: `find . -perm -o+w -not -path "./.git/*"`
5. For EACH security finding: create a GitHub Issue (type: BUG), assign milestone `new`

---

## PHASE 2 — ANALYSIS & TEAM PLANNING

Analyze the entire codebase:

| Category | Checkpoints |
|----------|------------|
| Code Quality | Duplicates, dead code, complexity, naming |
| Architecture | Separation of concerns, coupling, dependency structure |
| Security | Vulnerabilities, input validation, auth patterns |
| Performance | N+1 queries, unnecessary allocations, missing caching |
| Testing | Missing coverage, untested edge cases, test quality |
| Documentation | Missing/outdated docs, unclear APIs |
| Dependencies | Outdated, deprecated, unnecessary |

**Every finding becomes a GitHub Issue immediately** — never ask the user whether
to file one, and never hold findings back for a sign-off. Over-filing is
acceptable; asking is not.

For each improvement:
1. Check if an existing open issue already covers it → use that issue, don't duplicate
2. If new: create GitHub Issue (type: BUG or FEATURE), assign milestone `new`
3. Group related issues that should be handled by the same teammate

Determine team size (min 2, max 6). Each teammate gets an independent area. NO overlapping files. Assign issues to teammates.

Record in the run log and on the issues:
- Analysis results
- All GitHub Issues created/linked (with numbers)
- Proposed team structure (teammates, their issues, model choice, which skills/MCP each uses)

**Proceed straight to Phase 3 — never wait for user confirmation before creating
the team.** The work is gated by the Judge at Phases 4, 5 and 7, not by the
operator.

---

## PHASE 3 — SPAWN AGENT TEAM

### Model Policy
- **ALL teammates use newest Opus (see `c-bpm-sk-llm-selection`)** — no exceptions
- Document this in each task description

### Teammate Naming
Descriptive role names: `security-hardener`, `test-writer`, `code-cleaner`, `dep-updater`, `doc-improver`, `arch-refactorer`

### Spawn Form (the ONLY permitted form)
Every teammate is spawned as:

```
subagent_type: c-bpm-ag-teammate
isolation: "worktree"
mode: "plan"
```

There is no second spawn path. An unrestricted teammate — one holding `Bash`, `gh`, or a
shared working tree — must not be created for any reason, however urgent the task.
`c-bpm-ag-teammate` has **no `Bash`**: it cannot invoke the Judge CLI, cannot run `gh`, cannot
`git push`. The SoD gate is a capability the teammate lacks, not a rule it is asked to obey
(see #101). `mode: "plan"` remains a convenience, **not** the control — it demonstrably
failed to block Edit/Write.

### Gate of Record — Lead only
**A teammate's report is narrative, never state.** "Codex approved", "tests pass" and
"plan accepted" from a teammate advance *nothing*. The Team Lead invokes the Judge (via `c-bpm-sk-devils-advocate`), runs
the test suite, and performs every `gh` mutation itself, and posts each verdict as a
`## GATE` comment carrying a **nonce the Lead generated** (`NONCE=$(openssl rand -hex 8)`)
before that Codex run. A verdict whose nonce the Lead did not generate is **void**.

### Spawn Prompt Contents
Each teammate MUST receive, pasted into the prompt (it has no `gh` and no network):
- The **Issue body and comments**, fetched by the Lead via `gh api`
- Clear scope (which files/modules they own)
- Explicit boundaries (what they must NOT touch)
- Expected deliverables
- **Relevant skills** to use for their assigned work (from the list below)
- Instruction: send PLAN to team-lead BEFORE writing any code
- Instruction: **write the tests; do not run them** — you have no shell. The Team Lead runs
  the suite and Codex. Ask the Lead if you need a command run.

### Skill Selection per Teammate
Before spawning, review ALL available skills (`/skills` or check `~/.claude/skills/` and `.claude/skills/`). Assign relevant skills to each teammate based on their task:
- Security tasks -> `c-bpm-sk-appsec-threatlite`, `c-bpm-sk-tls-http-headers`, `c-bpm-sk-config-secrets`
- Bash scripts -> `c-bpm-sk-bash-secure-script`, `c-bpm-sk-curlbash-installer`
- Testing -> `c-bpm-sk-test-harness`
- API work -> `c-bpm-sk-api-contract`, `c-bpm-sk-php-crud-api-review`
- PHP work -> `c-bpm-sk-flightphp-pro`
- Redis -> `c-bpm-sk-redis-keyspace`
- Database -> `c-bpm-sk-mariadb-migrations`
- Release/CI -> `c-bpm-sk-release-ops`
- Repo structure -> `c-bpm-sk-repo-scaffold`
- UI/Frontend -> `frontend-design`
- n8n workflows -> `c-bpm-sk-n8n-reliability`, `n8n-*` skills
- Documentation -> `document-skills:*`

Include the relevant skill names in each teammate's spawn prompt so they can leverage specialized knowledge.

**Flagged skills do not auto-load — name them literally.** These skills carry `disable-model-invocation: true` and are NOT picked up by the natural-language router; a teammate that needs one only loads it if its exact skill name is in the spawn prompt. Always name them explicitly by name, never rely on a category phrase: `c-bpm-sk-linux-admin`, `c-bpm-sk-linux-archive`, `c-bpm-sk-linux-audit`, `c-bpm-sk-release-ops`. (Set + rationale pinned by `tests/bash/c-bpm-sk-library-cohesion.bats`, #143.)

---

## PHASE 4 — PLAN APPROVAL

Every teammate MUST submit a plan BEFORE writing code.

### Plan must contain:
1. **Files** — exact paths to be modified
2. **Changes** — what and why per file
3. **Test coverage plan** — which tests will be added/modified (MANDATORY!)
4. **Risk assessment** — what could break
5. **Rollback strategy** — how to undo

### Flow:
```
Teammate submits plan
  → Team Lead adds plan as comment to the GitHub Issue
  → Team Lead moves issue to milestone: planned
  → Team Lead reviews
  → Team Lead runs the independent review via `c-bpm-sk-devils-advocate`, asking the
    Judge to review this refactoring plan for <teammate-name>:
    completeness, test coverage, risk, safety. Approve or reject with reasons.
  → Judge verdict added as comment to the GitHub Issue
  → If BOTH approve → move issue to milestone: plan-approved
  → If EITHER rejects → issue stays at planned, rejection reason in comment, teammate revises
```

### Auto-Reject if:
- No test coverage plan
- Files outside assigned scope
- No rollback strategy
- Breaks existing interfaces without migration plan

---

## PHASE 5 — TEST DESIGN

After plan approval, teammate designs tests and submits test design to team-lead.

### Flow:
```
Teammate submits test design
  → Team Lead adds test design as comment to the GitHub Issue
  → Team Lead moves issue to milestone: test-designed
  → Team Lead reviews
  → Team Lead runs the independent review via `c-bpm-sk-devils-advocate`, asking the
    Judge to review the test designs for <teammate-name> (<test-file-paths>):
    edge cases, meaningful assertions, no false positives, adequate coverage.
    Approve or reject.
  → Judge verdict added as comment to the GitHub Issue
  → If BOTH approve → move issue to milestone: test-design-approved
  → If EITHER rejects → issue stays at test-designed, rejection reason in comment, teammate revises
```

---

## PHASE 6 — IMPLEMENTATION

After test design approval, teammate implements:
1. Work in the checked-out `main` working tree — **no feature branch.** This repo
   lands work by direct push to `main`; teammates never branch, never commit,
   never push.
2. Implement ONLY what was approved
3. Write tests FIRST (TDD preferred), then implementation
4. Run existing tests — nothing may break
5. Send completion message to team-lead with summary
6. Team Lead adds implementation summary as comment to the GitHub Issue
7. Team Lead moves issue to milestone: `implemented`

---

## PHASE 7 — TESTING & VERIFICATION

### 7a. Teammate Testing
1. Teammate runs their tests and reports results to team-lead
2. Team Lead adds test results as comment to the GitHub Issue
3. If tests pass → move issue to milestone: `tested-success`
4. If tests fail → move issue to milestone: `tested-failed`, document reason in comment, move back to `planned` (wrong approach) or `implemented` (code bug)

### 7b. Independent Verification by Lead and Codex
`tested-success` is NOT enough. The team lead and Codex must independently verify — do not blindly trust a teammate's test report.

```
Team Lead:
  → Run targeted tests for the changed files (not necessarily full suite, but enough to verify)
  → Spot-check the test quality: are assertions meaningful? edge cases covered?

Team Lead runs the independent review via `c-bpm-sk-devils-advocate`, asking the
  Judge to verify test results for <teammate-name> (changes: <summary>):
  are tests passing legitimately? Any false positives? Test coverage adequate?
  Approve or reject.

  → Verification results added as comment to the GitHub Issue
  → If BOTH approve → move issue to milestone: test-approved
  → If EITHER rejects → document reason, move back to implemented or planned
```

---

## PHASE 8 — LANDING (DIRECT TO MAIN) & SYNTHESIS

After all issues reach `test-approved`:

1. Team Lead lands the work **directly on `main`**:
   - **One commit per issue**, message `Issue #<N>: <summary>`, pushed straight to
     `main` with `git push`
   - **No pull requests, no feature branches, no merges** — this repo does not
     merge PRs; work that sits on a branch never lands
   - Each commit body references its issue: `Resolves #<number>` / `Part of #<number>`

2. Compile final refactoring report:
   - Discovery summary (MCP servers, skills found and used)
   - Existing issues addressed
   - Security findings
   - Changes per area
   - Test coverage before and after
   - All GitHub Issue numbers and their current milestone
   - Remaining recommendations → create new issues (type: FEATURE), milestone: `new`

3. Present report to user

4. **Do NOT move any issue to `DONE`** — only humans do that

5. Tell the user explicitly: "These issues are at `test-approved` and ready for your sign-off. Move them to `DONE` when you're satisfied: #1, #5, #8, ..."

---

## CODEX RULES

- Codex is the PRIMARY REVIEW AUTHORITY for all Claude-generated code
- The Judge MUST be invoked **only through `c-bpm-sk-devils-advocate`** — that skill
  owns the live-Issue fetch, the canonical sanitized command, and the ladder.
  Model and ladder policy live in `c-bpm-sk-llm-selection` — never restated here,
  never pinned in this file.
- Independent review is MANDATORY at 3 gates: plan approval, test design approval, test verification
- If every Judge tier is unreachable: STOP → notify user → do NOT proceed without an
  independent review
- Log all Judge verdicts as comments in the corresponding GitHub Issue, naming which
  Judge produced the verdict

---

## TEAMMATE LIFECYCLE (NON-NEGOTIABLE)

- **Shut down a teammate as soon as it has delivered.** A teammate that has sent
  its final report is finished — terminate it, do not keep it around as a
  resource.
- **A finished teammate can silently ignore further instructions.** `SendMessage`
  to a delivered teammate returns success with a `msg_id` and can still be a
  complete no-op: no files touched, no reply, no error surfaced (four teammates
  at once, file mtimes unchanged 70+ minutes later — issue #132; one of them only
  later surfaced an API connection failure). **A successful send is NOT evidence
  that work started.** This is a silent-failure risk, not merely context rot.
- **Never reuse a teammate that has already delivered.** Rework goes to a freshly
  spawned teammate carrying the full context in its spawn prompt — never to a
  follow-up message on a finished one.
- **Verify termination before spawning the replacement.** Confirm the old
  teammate is actually gone before the new one starts; two live teammates on the
  same files corrupt each other's work.
- Treat "no file change and no reply" as failure, not as work in progress:
  terminate and respawn.

---

## COORDINATION RULES

- Team Lead MUST stay in DELEGATE MODE at all times
- Team Lead does NOT: write code, edit files, run implementation commands, create test files
- Team Lead DOES: spawn teammates, send messages, manage tasks, run Codex reviews, manage GitHub Issues/Milestones via MCP, run targeted verification tests
- Communication via shared task list and messages
- File conflicts → Team Lead resolves by reassigning scope
- **All teammates use newest Opus (see `c-bpm-sk-llm-selection`)** — no model escalation needed
- Agent teams require: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to be set

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
