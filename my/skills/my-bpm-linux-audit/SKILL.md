---
name: my-bpm-linux-audit
description: Audit a Linux host for runtime conflicts, security issues, and system health. Creates one GitHub Issue per finding in the host's tracking repo (bpm-{hostname}). Runs as agent team with Codex-gated approvals, milestone tracking, and issue types (BUG/ENHANCEMENT). Use when onboarding a new server, after major changes, or on a regular schedule.
---

# my-bpm-linux-audit

## Overview

Full-system audit skill that inspects a Linux host across runtime environment, security baseline, and system health. Each finding becomes a separate GitHub Issue (type: BUG or ENHANCEMENT) with severity, category, current state, expected state, and fix steps. Designed for repeat runs — skips findings that already have an open issue.

Runs as an **agent team** with Team Lead (delegate mode), audit teammates, and Codex review gates. Follows the same orchestration pattern as `my-bpm-experteam-openissues` and `my-bpm-flightphp-pro`.

## Team Lead Role

You are the TEAM LEAD. You run in DELEGATE MODE.
- You implement NOTHING yourself — you coordinate, review, and approve ONLY
- You do NOT run audit commands yourself — teammates do that
- Your tools: spawning teammates, messaging, managing tasks, running Codex reviews, managing GitHub Issues/Milestones via MCP
- If you catch yourself about to run an audit command: STOP — delegate it to a teammate

---

## PHASE 0 — BOOTSTRAP (MANDATORY FIRST)

This phase MUST complete before any audit work. Team Lead executes this directly (exception to delegate mode — infrastructure setup only).

### 0a–0d. Bootstrap Checks

Run all bootstrap checks from `references/audit-checklist.md` → **Bootstrap** section:
1. **Determine host identity** — `hostname`, derive repo name `bpm-{hostname}`, org `BPMspaceUG`
2. **Check user `rootmessages`** — MUST exist with `sudo NOPASSWD: ALL`. If missing → create (requires human confirmation)
3. **Check host-repo** — search GitHub for `bpm-{hostname}` in org. **Chicken-egg rule:** if repo does NOT exist, create it first, then retroactively document by creating Issue #1: "Host-Repo bootstrap for {hostname}" (date, creator, purpose, hostname, OS, IP). This is the ONE exception where an action happens before an issue exists.
4. **Local clone** — ensure `/home/rootmessages/bpm-{hostname}/` is cloned and up to date

### 0e. Create Lifecycle Milestones (MANDATORY — DO NOT SKIP)

**This step MUST complete before spawning any teammates.** List existing milestones first, then create any missing ones via GitHub MCP (`gh api repos/{ORG}/{REPO}/milestones`):

```
new, planned, plan-approved, test-designed, test-design-approved,
implemented, tested-success, tested-failed, test-approved, DONE
```

Skip any milestone that already exists. **Record the milestone numbers** (e.g., `new`=#1) — teammates need these to set milestones on created issues.

### 0f. Verify Bootstrap Completion

Before proceeding to Phase 1, confirm ALL of these:
- [ ] `rootmessages` user exists with NOPASSWD sudo
- [ ] Host-repo exists on GitHub
- [ ] Local clone is up to date
- [ ] All 10 milestones exist
- [ ] Milestone numbers are noted

**If ANY check fails: STOP and fix it before proceeding.**

---

## PHASE 1 — AUDIT TEAM PLANNING

### 1a. Team Structure

Spawn **3 audit teammates** (all Opus 4.6), each responsible for one audit category:

| Teammate | Category | Scope |
|---|---|---|
| `runtime-auditor` | Runtime Environment | PATH, symlinks, runtimes, version managers |
| `security-auditor` | Security Baseline | SSH, firewall, updates, sudo, fail2ban |
| `health-auditor` | System Health | Kernel, disk, memory, services, Docker, backups |

### 1b. Present Plan to User

Show the team plan and **WAIT for confirmation** before spawning.

---

## PHASE 2 — SPAWN AUDIT TEAM

### Model Policy
- **ALL teammates use Opus 4.6** — no exceptions

### Teammate Instructions

Each teammate receives ALL of the following in their spawn prompt:
1. Their audit category and the **exact commands** to run (copy from `references/audit-checklist.md`)
2. The host-repo: `owner: {ORG}`, `repo: {REPO}`
3. The **milestone number for `new`** (e.g., `milestone: 1`) — looked up in Phase 0e
4. **Instructions (include verbatim in spawn prompt):**
   - Run ALL checks in your category — do not skip any
   - For EACH finding that needs action, create a GitHub Issue via `mcp__github__issue_write` with:
     - `method: "create"`
     - `owner`, `repo` as provided
     - `title`: descriptive title
     - `milestone`: the number for `new` milestone (provided above)
     - `body`: use the exact Issue Format from Phase 4 below
   - Use issue type: **BUG** (broken/insecure/wrong) or **ENHANCEMENT** (improvement/recommendation)
   - **BEFORE creating any issue**, search existing open issues: `mcp__github__search_issues query:"<keywords>" owner:{ORG} repo:{REPO}`
   - If a matching open issue exists → skip and log as "already tracked: #N"
   - **EVERY created issue MUST have the `new` milestone set** — this is NON-NEGOTIABLE
   - After all issues are created, send a summary to team-lead listing: all findings, issues created (with numbers), issues skipped (with references)

### Plan Mode
All teammates MUST be spawned with `mode: "plan"` — plan approval required before creating issues.

---

## PHASE 3 — PLAN APPROVAL (CODEX-GATED)

Each teammate submits their findings list as a plan.

### Plan Requirements (AUTO-REJECT if missing):
1. **Findings** — what was found, with concrete command output
2. **Proposed issues** — title, type (BUG/ENHANCEMENT), severity for each
3. **Dedup check** — confirmation that no matching open issue exists

### Approval Flow:
```
Teammate submits plan (via ExitPlanMode)
  → Team Lead reviews findings
  → Team Lead executes Codex review:

    codex exec --skip-git-repo-check "Review these Linux audit findings for host {hostname}.
    Category: {category}. Findings: {findings-summary}.
    Check: 1) Severity ratings are appropriate. 2) No false positives.
    3) Fix steps are correct and safe. 4) Issue types (BUG vs ENHANCEMENT) are correct.
    Approve or reject with reasons."

  → If BOTH approve → teammate proceeds to create issues
  → If EITHER rejects → teammate revises findings
```

---

## PHASE 4 — ISSUE CREATION

After plan approval, each teammate creates their issues:

### Issue Format

```markdown
## Severity: {Critical|High|Medium|Low|Info}
**Category:** {Runtime|Security|Health|Config}
**Type:** {BUG|ENHANCEMENT}

## Current State
{What was found — concrete command output}

## Expected State
{What it should look like}

## Fix Steps
{Numbered concrete commands to fix the issue}
```

### Issue Rules (MANDATORY — teammates MUST follow these exactly)
- **Type**: BUG or ENHANCEMENT — prefix in title: `[BUG]` or `[ENHANCEMENT]`
- **Milestone**: MUST be set to `new` (milestone number provided in spawn prompt) — **NO ISSUE WITHOUT MILESTONE**
- **No labels** — milestones are the only lifecycle tracker
- **Dedup**: search before create — skip if matching open issue exists
- **Log**: skipped findings reported as "already tracked: #{issue-number}"
- **One issue per finding** — never combine multiple findings into one issue

---

## PHASE 5 — AUDIT SUMMARY

After all teammates have created their issues, Team Lead:
1. **Verifies milestones** — list all open issues, confirm EVERY audit issue has milestone `new` set. If any is missing, fix it immediately via `mcp__github__issue_write`
2. Compiles the summary

### Summary Format

Post as a new issue titled "Audit Run {YYYY-MM-DD}":

```markdown
## Audit Summary — {hostname} — {date}

**OS:** {os-version}
**Kernel:** {kernel-version}
**Uptime:** {uptime}

### Findings

| # | Finding | Type | Severity | Issue | Status |
|---|---|---|---|---|---|
| 1 | Node.js shadowed by Bun | BUG | Critical | #13 | already open |
| 2 | SSH PasswordAuth enabled | BUG | High | #15 | NEW |
| 3 | No fail2ban installed | ENHANCEMENT | Medium | #16 | NEW |

### Totals
- **X** findings total
- **Y** new issues created
- **Z** already tracked (skipped)
- **Critical:** N | **High:** N | **Medium:** N | **Low:** N | **Info:** N

### Bootstrap Status
- [x] User `rootmessages` exists with sudo NOPASSWD
- [x] Host-repo `bpm-{hostname}` exists
- [x] Local clone synced
```

### Codex Final Review

```bash
codex exec --skip-git-repo-check "Review this Linux audit summary for host {hostname}.
Check: 1) All major audit areas covered (runtime, security, health).
2) Severity ratings consistent. 3) No critical findings missed.
4) Summary is complete. Summary: {summary-content}"
```

Post Codex review result as comment on the Audit Run issue.

---

## PHASE 6 — SHUTDOWN

After summary is posted:
1. Send shutdown requests to all teammates
2. Present final summary to user
3. List all open issues in the host-repo for user review
4. **Do NOT fix any issues** — this skill AUDITS only, fixes are separate work

---

## Audit Categories — Quick Reference

### A. Runtime Environment
Read: `references/audit-checklist.md` section A

- PATH shadowing (`/usr/local/bin/` vs `/usr/bin/`)
- Multiple runtime versions in PATH
- User-local runtime dirs (`.bun/`, `.nvm/`, `.pyenv/`, `.deno/`)
- PATH manipulation in profile scripts
- System runtime versions

### B. Security Baseline
Read: `references/audit-checklist.md` section B

- SSH config (PasswordAuth, PermitRoot, Key-Only)
- Firewall (ufw/nftables)
- Pending security updates
- Sudo users and NOPASSWD
- Fail2ban / intrusion prevention
- Unattended upgrades

### C. System Health
Read: `references/audit-checklist.md` section C

- Kernel (running vs installed)
- Disk space and SMART
- Memory and swap
- Failed systemd services
- Docker containers and images
- Systemd timers
- Backups (count, age)

---

## Issue Type Reference

| Type | When | Examples |
|---|---|---|
| **BUG** | Something is broken, insecure, or wrong | Symlink shadowing, SSH misconfigured, failed services |
| **ENHANCEMENT** | Improvement or recommendation | Install fail2ban, set up version manager, add backup rotation |

No labels. No tags. Issue type + milestone = full lifecycle tracking.

---

## Codex Rules (NON-NEGOTIABLE)

- Codex is the **PRIMARY REVIEW AUTHORITY** for all findings
- Codex MUST be invoked **ONLY via shell**: `codex exec --skip-git-repo-check "<prompt>"`
- Codex review is **MANDATORY** at 2 gates:
  1. Findings approval (Phase 3)
  2. Audit summary review (Phase 5)
- If Codex is unavailable: **STOP → notify user → do NOT proceed without Codex**
- Log ALL Codex responses as comments on the Audit Run issue

---

## Segregation of Duty

- **Audit teammates** run commands and prepare findings
- **Codex** reviews and approves findings via `codex exec`
- **Team Lead** coordinates but NEVER runs audit commands
- No LLM reviews its own work
- All approvals documented in GitHub Issues

---

## Coordination Rules

- Team Lead MUST stay in DELEGATE MODE at all times (except Phase 0 bootstrap)
- Communication via shared task list and messages
- **All teammates use Opus 4.6**
- Agent teams require: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
