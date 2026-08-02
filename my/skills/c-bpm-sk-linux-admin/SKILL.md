---
name: c-bpm-sk-linux-admin
description: "Linux admin fixes — fix audit findings, implement server fixes, Debian/Ubuntu admin, host remediation. Works on bpm-{hostname} repo issues. Agent team with Codex gates."
user-invocable: true
disable-model-invocation: true
enforcement: block
intentPatterns: "fix audit findings;;linux admin fix;;server (remediation|fix);;implement (server|host) fixes;;host remediation"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Task, Teammate, SendMessage
---

# c-bpm-sk-linux-admin

## Overview

Expert Linux administration skill that **implements fixes** for issues found by `c-bpm-sk-linux-audit`. Reads open issues from the host's tracking repo (`bpm-{hostname}`), triages them by severity, and assigns them to specialist teammates to produce remediation plans and exact command proposals for Team Lead execution.

Runs as an **agent team** with Team Lead operating as a **shell broker** and admin teammates operating without shell access. Follows the same orchestration pattern as `c-bpm-cm-experteam-openissues`.

**This skill IMPLEMENTS — it does NOT audit.** Use `c-bpm-sk-linux-audit` first to create findings, then this skill to fix them.

## Team Lead Role

You are the TEAM LEAD. You run in SHELL-BROKER DELEGATE MODE.
- You are the sole shell holder and sole executor of Phase 0 bootstrap and all approved fix, rollback, and verification commands
- Teammates do NOT have shell access and must NEVER run commands themselves
- Teammates PROPOSE plans, exact commands, validation, rollback, and risk analysis; you review, approve, execute, and report
- Your tools: shell execution, spawning teammates, messaging, managing tasks, running Codex reviews, managing GitHub Issues/Milestones via MCP
- If a teammate plan or prompt implies that a teammate will execute, validate, or roll back commands: STOP and rewrite it so execution is Team Lead-scoped

---

## PHASE 0 — BOOTSTRAP (MANDATORY FIRST)

This phase MUST complete before any fix work. Team Lead executes this directly (exception to delegate mode — infrastructure setup only).

### 0a. Determine Host Identity

```bash
HOSTNAME=$(hostname)
REPO="bpm-${HOSTNAME}"
ORG="BPMspaceUG"
```

### 0b. Check User `rootmessages`

```bash
id rootmessages 2>/dev/null
sudo -l -U rootmessages 2>/dev/null | grep "NOPASSWD: ALL"
```

- MUST exist with `sudo NOPASSWD: ALL`
- If missing → STOP and notify user (creating system users requires human confirmation)

### 0c. Check Host-Repo

Search GitHub for `bpm-{hostname}` in org BPMspaceUG via MCP.
- If repo does NOT exist → create it via `mcp__github__create_repository` (name: `bpm-{hostname}`, org: BPMspaceUG, private: true, autoInit: true)
- Then retroactively create Issue #1: "Host-Repo bootstrap for {hostname}"

### 0d. Local Clone

```bash
ls -d /home/rootmessages/bpm-${HOSTNAME}/.git 2>/dev/null
```

If not cloned: clone to `/home/rootmessages/bpm-${HOSTNAME}/`. If exists: `git pull`.

### 0e. Verify Milestones

List existing milestones. All 11 lifecycle milestones MUST exist:

```
new, planned, plan-approved, test-designed, test-design-approved,
implemented, tested-success, tested-failed, test-approved, DONE, CANCELLED
```

Create any that are missing. **Record milestone numbers** — teammates need these.

### 0f. System Snapshot

Collect basic system info for context (Team Lead may run these directly — read-only):

```bash
uname -r
cat /etc/os-release | grep -E "^(NAME|VERSION)="
uptime -p
free -h | head -2
df -h | grep "^/dev"
```

### 0g. Verify Bootstrap Completion

Before proceeding to Phase 1, confirm ALL of these:
- [ ] `rootmessages` user exists with NOPASSWD sudo
- [ ] Host-repo exists on GitHub
- [ ] Local clone is up to date
- [ ] All 10 milestones exist with numbers noted
- [ ] System snapshot captured

**If ANY check fails: STOP and fix it before proceeding.**

---

## PHASE 1 — ISSUE INVENTORY & TRIAGE

### 1a. Fetch All Open Issues

Using GitHub MCP, fetch ALL open issues from `bpm-{hostname}`.

### 1b. Triage & Classify

For each open issue:
- Read the full issue body (severity, category, current state, expected state, fix steps)
- Classify implementation complexity: SIMPLE (single command), MODERATE (multi-step), COMPLEX (architectural change)
- Note dependencies between issues
- Flag issues that are BLOCKED on human action — these will NOT be assigned

### 1c. Priority Order

Sort workable issues by:
1. **Critical** severity first
2. **BUG** before **ENHANCEMENT** at same severity
3. Dependencies resolved (prerequisites first)
4. **High → Medium → Low → Info**

### 1d. Risk Assessment

For each issue, assess:
- **Blast radius**: Does this affect running services? Other users? Network connectivity?
- **Reversibility**: Can the change be undone? What's the rollback?
- **Downtime**: Does this require a reboot or service restart?

Flag any issue that could cause loss of SSH access, service downtime, data loss, or network partition. These require **explicit user confirmation** before proceeding.

---

## PHASE 2 — TEAM PLANNING

### 2a. Team Sizing

- Minimum: 1 teammate (if only 1-2 simple issues)
- Maximum: 4 teammates
- Group issues by domain:

| Teammate Role | Issue Types |
|---|---|
| `runtime-admin` | PATH fixes, symlink cleanup, runtime installs/removals, version managers |
| `security-admin` | SSH hardening, firewall rules, fail2ban, sudo config, updates |
| `system-admin` | Disk cleanup, Docker maintenance, service fixes, kernel, backups |
| `network-admin` | UFW/nftables rules, port management, Docker networking |

Only spawn roles that have issues assigned. Skip empty categories.

### 2b. Present Plan to User

Show:
1. System snapshot from Phase 0
2. All open issues with severity, type, and complexity
3. Which issues are BLOCKED (and why)
4. Which issues need user confirmation (risky changes)
5. Proposed team structure with issue assignments
6. Execution order (dependencies respected)

**WAIT for user confirmation before spawning teammates.**

---

## PHASE 3 — SPAWN ADMIN TEAM

### Model Policy
- **ALL teammates use newest Opus (see `c-bpm-sk-llm-selection`)** — no exceptions

### Teammate Instructions

Each teammate receives ALL of the following in their spawn prompt:

1. Their assigned issues (full issue body with fix steps)
2. The host-repo: `owner: {ORG}`, `repo: {REPO}`
3. The **milestone numbers** for lifecycle transitions
4. The system snapshot (OS, kernel, etc.)
5. **Instructions (include verbatim in spawn prompt):**

Read: `references/admin-instructions.md` for the full teammate instruction block.

Key points:
- You are a **Debian/Ubuntu Linux expert** operating without shell access
- **BEFORE any execution**, submit a plan via ExitPlanMode
- Plan MUST include: pre-checks for Team Lead, exact commands for Team Lead to run, validation commands for Team Lead to run, rollback commands for Team Lead to run, and risk assessment
- After plan approval: stay available while Team Lead executes, then interpret results and recommend next steps
- Never use `sudo` or claim you executed anything; only Team Lead executes shell commands
- Safety rules from `references/safety-rules.md` are NON-NEGOTIABLE

### Plan Mode
All teammates MUST be spawned with `mode: "plan"` — plan approval required before any changes.

---

## PHASE 4 — PLAN APPROVAL (CODEX-GATED)

Every teammate MUST submit a plan BEFORE any fix execution.

### Plan Requirements (AUTO-REJECT if missing):
1. **Pre-checks** — what Team Lead must verify before changing anything
2. **Commands** — exact commands Team Lead will run, in order
3. **Validation** — exact commands Team Lead will run to verify the fix worked
4. **Rollback** — exact commands Team Lead will run if anything goes wrong
5. **Risk assessment** — what could break

### Approval Flow:
```
Teammate submits plan (via ExitPlanMode)
  → Team Lead reviews plan for safety, completeness, correctness
  → Team Lead posts plan as comment on the GitHub Issue
  → Team Lead updates issue milestone to `planned`
  → Team Lead runs the independent review via `c-bpm-sk-devils-advocate`
    (Issue #<N>), asking the Judge to check:
     1) Pre-checks verify current state. 2) Commands correct for Debian/Ubuntu.
     3) Validation confirms fix. 4) Rollback is safe and complete.
     5) No risk of SSH lockout, data loss, or service disruption.
     Approve or reject with specific reasons.

  → Codex result posted as comment on the GitHub Issue
  → If BOTH approve → milestone to `plan-approved`, approve teammate's execution package for Team Lead execution
  → If EITHER rejects → reject with reasons, teammate revises
```

### Auto-Reject Criteria:
- No pre-checks / no rollback / no validation
- Commands that could cause SSH lockout
- Firewall changes without SSH safeguard
- Package removal without dependency check
- Missing risk assessment

---

## PHASE 5 — IMPLEMENTATION

After plan approval, Team Lead executes the fix using the approved teammate plan:

1. Team Lead runs the pre-checks — if any fail, STOP and report in the GitHub Issue; teammate revises the plan
2. Team Lead executes the fix commands in order
3. Team Lead runs the validation steps
4. Team Lead records all commands, output, and validation results, and shares them with the teammate if interpretation or replanning is needed
5. Team Lead updates milestone to `implemented`
6. Team Lead posts implementation summary as comment on the GitHub Issue

**If anything goes wrong:**
- Team Lead executes the approved rollback immediately
- Team Lead reports failure to the teammate and in the GitHub Issue
- Team Lead updates milestone to `tested-failed`
- Issue stays open for re-planning

---

## PHASE 6 — VERIFICATION (CODEX-GATED)

### 6a. Team Lead Captures Results

Verification evidence: Team Lead command output proving fix applied, before/after comparison, and confirmation of no side effects.

### 6b. Independent Verification

```
Team Lead:
  → Reviews verification evidence
  → Runs the approved verification commands
  → Posts verification results as comment on GitHub Issue

Team Lead runs the independent review via `c-bpm-sk-devils-advocate` (Issue #<N>),
  asking the Judge to verify the applied fix and the verification evidence:
  1) Fix correctly applied. 2) No side effects. 3) Validation genuine.
  4) System in expected state. Approve or reject with reasons.

  → If BOTH approve → milestone to `tested-success` → `test-approved` → close issue
  → If EITHER rejects → milestone to `tested-failed`, teammate revises the plan/command set
```

---

## PHASE 7 — SYNTHESIS & REPORT

After all workable issues are addressed:

1. Compile final report:
   - System snapshot (before)
   - Issues fixed (with milestone transitions)
   - Issues still open (and why)
   - Issues needing user action
   - Verification summary

2. Post report as comment on the latest Audit Run issue (if one exists)

3. Final independent review via `c-bpm-sk-devils-advocate` — ask the Judge to review
   the session report for host {hostname}: 1) All fixes properly verified.
   2) No security regressions. 3) System stability maintained.
   4) Rollback plans documented.

4. Present final report to user

---

## PHASE 8 — SHUTDOWN

1. Send shutdown requests to all teammates
2. List all remaining open issues for user review
3. Recommend next steps (re-audit, manual fixes, scheduled tasks)

---

## Codex Rules (NON-NEGOTIABLE)

- Independent review is **MANDATORY** for all fixes
- The Judge MUST be invoked **only through `c-bpm-sk-devils-advocate`** — that skill
  owns the live-Issue fetch, the canonical sanitized command, and the ladder
- Independent review is **MANDATORY** at 2 gates: Plan approval (Phase 4), Verification (Phase 6)
- Log ALL reviewer responses as comments on the corresponding GitHub Issue

### If the Judge Is Unavailable

`c-bpm-sk-devils-advocate` descends the substitute-Judge ladder defined in
`c-bpm-sk-llm-selection`. If every tier is unreachable:
- **Notify the user** immediately
- **Do NOT proceed** without at least one independent review
- Log which reviewer was used in all review comments

---

## Segregation of Duty

- **Admin teammates** propose remediation plans, exact commands, validation, and rollback steps; they never execute shell commands
- **Independent reviewer** (Codex/Gemini/other) reviews and approves plans and results
- **Team Lead** is the sole executor of Phase 0 bootstrap and all fix, rollback, and verification commands
- No LLM reviews its own work
- All approvals documented in GitHub Issues

---

## Milestone Lifecycle

```
new → planned → plan-approved → implemented → tested-success → test-approved → DONE
                                            ↘ tested-failed → (back to planned)
any state except DONE → CANCELLED   (human-only, terminal abort)
```

Team Lead manages ALL milestone transitions. Teammates recommend but do not set milestones.

See `c-bpm-sk-milestone-type` for full milestone definitions and transition rules.

---

## Coordination Rules

- Team Lead MUST stay in SHELL-BROKER DELEGATE MODE: delegate analysis and planning to teammates, but retain all shell execution
- Communication via shared task list and messages
- **All teammates use newest Opus (see `c-bpm-sk-llm-selection`)**
- Agent teams require: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
