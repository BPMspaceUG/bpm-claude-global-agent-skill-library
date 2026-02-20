---
name: my-linux-admin
description: Debian/Ubuntu Linux expert that implements fixes from audit findings. Works on open issues in a host's tracking repo (bpm-{hostname}). Runs as agent team with Codex-gated plan approval, test design approval, and test verification. Segregation of Duty enforced. Use after my-linux-audit has created issues.
---

# my-linux-admin

## Overview

Expert Linux administration skill that **implements fixes** for issues found by `my-linux-audit`. Reads open issues from the host's tracking repo (`bpm-{hostname}`), triages them by severity, and assigns them to specialist teammates for implementation.

Runs as an **agent team** with Team Lead (delegate mode), admin teammates, and Codex review gates. Follows the same orchestration pattern as `my-experteam-openissues`.

**This skill IMPLEMENTS — it does NOT audit.** Use `my-linux-audit` first to create findings, then this skill to fix them.

## Team Lead Role

You are the TEAM LEAD. You run in DELEGATE MODE.
- You implement NOTHING yourself — you coordinate, review, and approve ONLY
- You do NOT run fix commands yourself — teammates do that
- Your tools: spawning teammates, messaging, managing tasks, running Codex reviews, managing GitHub Issues/Milestones via MCP
- If you catch yourself about to run a fix command or edit a config file: STOP — delegate it to a teammate

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

List existing milestones. All 10 lifecycle milestones MUST exist:

```
new, planned, plan-approved, test-designed, test-design-approved,
implemented, tested-success, tested-failed, test-approved, DONE
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
- **ALL teammates use Opus 4.6** — no exceptions

### Teammate Instructions

Each teammate receives ALL of the following in their spawn prompt:

1. Their assigned issues (full issue body with fix steps)
2. The host-repo: `owner: {ORG}`, `repo: {REPO}`
3. The **milestone numbers** for lifecycle transitions
4. The system snapshot (OS, kernel, etc.)
5. **Instructions (include verbatim in spawn prompt):**

Read: `references/admin-instructions.md` for the full teammate instruction block.

Key points:
- You are a **Debian/Ubuntu Linux expert**
- **BEFORE implementing anything**, submit a plan via ExitPlanMode
- Plan MUST include: pre-checks, exact commands, validation, rollback, risk assessment
- After plan approval: implement, validate, report results to team-lead
- Use `sudo` for privileged operations
- Safety rules from `references/safety-rules.md` are NON-NEGOTIABLE

### Plan Mode
All teammates MUST be spawned with `mode: "plan"` — plan approval required before any changes.

---

## PHASE 4 — PLAN APPROVAL (CODEX-GATED)

Every teammate MUST submit a plan BEFORE implementing any fix.

### Plan Requirements (AUTO-REJECT if missing):
1. **Pre-checks** — what to verify before changing anything
2. **Commands** — exact commands to run, in order
3. **Validation** — how to verify the fix worked
4. **Rollback** — how to undo if something goes wrong
5. **Risk assessment** — what could break

### Approval Flow:
```
Teammate submits plan (via ExitPlanMode)
  → Team Lead reviews plan for safety, completeness, correctness
  → Team Lead posts plan as comment on the GitHub Issue
  → Team Lead updates issue milestone to `planned`
  → Team Lead executes Codex review:

     codex exec --skip-git-repo-check "Review this Linux administration fix plan
     for Issue #<N> on a Debian/Ubuntu host. Plan: <plan-summary>.
     REQUIREMENTS: 1) Pre-checks verify current state. 2) Commands correct for
     Debian/Ubuntu. 3) Validation confirms fix. 4) Rollback is safe and complete.
     5) No risk of SSH lockout, data loss, or service disruption.
     Approve or reject with specific reasons."

  → Codex result posted as comment on the GitHub Issue
  → If BOTH approve → milestone to `plan-approved`, approve teammate's plan
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

After plan approval, teammate implements the fix:

1. Run pre-checks — if any fail, STOP and report to team-lead
2. Execute fix commands in order
3. Run validation steps
4. Send completion message to team-lead with all commands, output, and validation results
5. Team Lead updates milestone to `implemented`
6. Team Lead posts implementation summary as comment on the GitHub Issue

**If anything goes wrong:**
- Teammate executes rollback immediately
- Reports failure to team-lead
- Team Lead updates milestone to `tested-failed`
- Issue stays open for re-planning

---

## PHASE 6 — VERIFICATION (CODEX-GATED)

### 6a. Teammate Reports Results

Verification evidence: command output proving fix applied, before/after comparison, no side effects.

### 6b. Independent Verification

```
Team Lead:
  → Reviews verification evidence
  → May run read-only verification commands (exception to delegate mode)
  → Posts verification results as comment on GitHub Issue

Team Lead executes:
  codex exec --skip-git-repo-check "Verify this Linux administration fix for
  Issue #<N>. Fix applied: <summary>. Verification: <evidence>.
  Check: 1) Fix correctly applied. 2) No side effects. 3) Validation genuine.
  4) System in expected state. Approve or reject with reasons."

  → If BOTH approve → milestone to `tested-success` → `test-approved` → close issue
  → If EITHER rejects → milestone to `tested-failed`, teammate revises
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

3. Final Codex review:
   ```bash
   codex exec --skip-git-repo-check "Review this Linux administration session
   report for host {hostname}. Check: 1) All fixes properly verified.
   2) No security regressions. 3) System stability maintained.
   4) Rollback plans documented. Report: {report-content}"
   ```

4. Present final report to user

---

## PHASE 8 — SHUTDOWN

1. Send shutdown requests to all teammates
2. List all remaining open issues for user review
3. Recommend next steps (re-audit, manual fixes, scheduled tasks)

---

## Codex Rules (NON-NEGOTIABLE)

- Codex is the **PRIMARY REVIEW AUTHORITY** for all fixes
- Codex MUST be invoked **ONLY via shell**: `codex exec --skip-git-repo-check "<prompt>"`
- Codex review is **MANDATORY** at 2 gates: Plan approval (Phase 4), Verification (Phase 6)
- If Codex is unavailable: **STOP → notify user → do NOT proceed without Codex**
- Log ALL Codex responses as comments on the corresponding GitHub Issue

---

## Segregation of Duty

- **Admin teammates** run commands and implement fixes
- **Codex** reviews and approves plans and results via `codex exec`
- **Team Lead** coordinates but NEVER implements
- No LLM reviews its own work
- All approvals documented in GitHub Issues

---

## Milestone Lifecycle

```
new → planned → plan-approved → implemented → tested-success → test-approved → DONE
                                            ↘ tested-failed → (back to planned)
```

Team Lead manages ALL milestone transitions. Teammates recommend but do not set milestones.

---

## Coordination Rules

- Team Lead MUST stay in DELEGATE MODE at all times (except Phase 0 bootstrap and read-only verification)
- Communication via shared task list and messages
- **All teammates use Opus 4.6**
- Agent teams require: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
