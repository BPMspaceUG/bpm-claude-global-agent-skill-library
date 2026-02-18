---
name: my-seo-auditor
description: Orchestrator that runs all 3 SEO skills (seo-audit, programmatic-seo, seo-geo) against a target website as a team with separation of duties and Codex approval. Triggers on /my-seo-auditor <url>, /my-seo-audit-ico, /my-seo-audit-mitsm, or when the user asks for a full multi-skill SEO audit.
---

# SEO Auditor Orchestrator

Run a comprehensive SEO audit against a target website using three specialist skills in parallel, with Codex as the primary review authority.

## Usage

```
/my-seo-auditor <website-url>
```

Called by project commands:
- `/my-seo-audit-ico` → `https://ico-cert.org`
- `/my-seo-audit-mitsm` → `https://www.mitsm.de`

## Prerequisites (MUST pass on first invocation)

This skill requires 3 external skills to be installed locally in the project:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
MISSING=0
for skill in seo-audit programmatic-seo seo-geo; do
  if [ ! -f "$PROJECT_ROOT/.agents/skills/$skill/SKILL.md" ]; then
    echo "PREREQUISITE FAIL: Missing skill '$skill' at .agents/skills/$skill/SKILL.md"
    MISSING=1
  else
    echo "PREREQUISITE OK: $skill found"
  fi
done
if [ "$MISSING" -eq 1 ]; then
  echo "ACTION: Install missing skills with: npx skills add <repo-url> --skill <name> --yes"
  echo "  seo-audit + programmatic-seo: https://github.com/coreyhaines31/marketingskills"
  echo "  seo-geo: https://github.com/resciencelab/opc-skills"
  exit 1
fi
echo "All 3 prerequisite skills present."
```

Also requires `codex` CLI on PATH:
```bash
which codex >/dev/null 2>&1 || { echo "PREREQUISITE FAIL: codex not found on PATH"; exit 1; }
echo "Codex found: $(codex --version)"
```

**Rule:** If any prerequisite fails, STOP and print install instructions. Do NOT proceed.

## Pre-Flight Checks (MUST pass before any work)

Order: validate environment → security check BEFORE update → update → re-check.

```bash
TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S")

# 0. Validate git environment
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  echo "PRE-FLIGHT FAIL: Not inside a git repository."
  exit 1
fi

# 1. Security gate FIRST — check each skill repo for uncommitted changes BEFORE pulling
for skill in seo-audit programmatic-seo seo-geo; do
  SKILL_DIR="$PROJECT_ROOT/.agents/skills/$skill"
  if [ -d "$SKILL_DIR/.git" ]; then
    DIRTY=$(cd "$SKILL_DIR" && git status --porcelain 2>/dev/null)
    if [ -n "$DIRTY" ]; then
      echo "SECURITY FAIL: Uncommitted changes in $skill:"
      echo "$DIRTY"
      echo "ACTION: Inspect $SKILL_DIR manually. Do NOT proceed."
      exit 1
    fi
  fi
done
echo "SECURITY PASS: All skill repos clean."

# 2. Update skill repos (network step — after security check)
UPDATE_FAILED=0
for skill in seo-audit programmatic-seo seo-geo; do
  SKILL_DIR="$PROJECT_ROOT/.agents/skills/$skill"
  if [ -d "$SKILL_DIR/.git" ]; then
    if ! (cd "$SKILL_DIR" && git pull 2>&1); then
      echo "UPDATE WARNING: git pull failed for $skill (network/auth issue)"
      UPDATE_FAILED=1
    fi
  else
    echo "UPDATE SKIP: $skill is not a git repo (installed via npx skills)"
  fi
done
if [ "$UPDATE_FAILED" -eq 1 ]; then
  echo "WARNING: Some skill updates failed. Proceeding with local versions."
fi

# 3. Post-update security re-check
for skill in seo-audit programmatic-seo seo-geo; do
  SKILL_DIR="$PROJECT_ROOT/.agents/skills/$skill"
  if [ -d "$SKILL_DIR/.git" ]; then
    DIRTY=$(cd "$SKILL_DIR" && git status --porcelain 2>/dev/null)
    if [ -n "$DIRTY" ]; then
      echo "SECURITY FAIL: Unexpected changes after update in $skill:"
      echo "$DIRTY"
      exit 1
    fi
  fi
done
echo "PRE-FLIGHT COMPLETE: All checks passed."
```

**Pass/fail rules:**
- If `git rev-parse` fails → STOP (not in a git repo)
- If any skill repo has uncommitted changes before pull → STOP
- If `git pull` fails → WARN but continue with local versions (no network is not fatal)
- If unexpected changes appear after pull → STOP

## Team Creation (explicit steps)

Use the `TeamCreate` tool to create the team, then spawn each agent with the `Task` tool:

```
1. TeamCreate: team_name="seo-audit-{TIMESTAMP}", description="SEO audit of {WEBSITE_URL}"

2. Task: name="skill-1-auditor", subagent_type="general-purpose", model="opus", mode="plan", team_name="seo-audit-{TIMESTAMP}"
   Prompt: "Read .agents/skills/seo-audit/SKILL.md. Audit {WEBSITE_URL} following the skill methodology. Write report to reports/{slug}/{TIMESTAMP}/skill-1-seo-audit.md using the template in ~/.claude/skills/my-seo-auditor/references/report-template.md (Individual Skill Report Template section)."

3. Task: name="skill-2-pseo", subagent_type="general-purpose", model="opus", mode="plan", team_name="seo-audit-{TIMESTAMP}"
   Prompt: "Read .agents/skills/programmatic-seo/SKILL.md. Analyze {WEBSITE_URL} following the skill methodology. Write report to reports/{slug}/{TIMESTAMP}/skill-2-programmatic-seo.md using the template in ~/.claude/skills/my-seo-auditor/references/report-template.md (Individual Skill Report Template section)."

4. Task: name="skill-3-geo", subagent_type="general-purpose", model="opus", mode="plan", team_name="seo-audit-{TIMESTAMP}"
   Prompt: "Read .agents/skills/seo-geo/SKILL.md. Analyze {WEBSITE_URL} following the skill methodology. Write report to reports/{slug}/{TIMESTAMP}/skill-3-seo-geo.md using the template in ~/.claude/skills/my-seo-auditor/references/report-template.md (Individual Skill Report Template section)."

5. Task: name="consensus-synthesizer", subagent_type="general-purpose", model="opus", mode="plan", team_name="seo-audit-{TIMESTAMP}"
   Prompt: (launched AFTER Phase 2 — see workflow below)
```

Agents 1-3 launch IN PARALLEL. Agent 4 launches after Phase 2.

## Separation of Duties

| Actor | Responsibility | Tool |
|-------|---------------|------|
| **Agents 1-3** | Produce individual skill reports | Task tool (general-purpose, model="opus", mode="plan") |
| **Team Lead** | Orchestrate, coordinate, verify completeness | TeamCreate, Task, SendMessage |
| **Codex** | PRIMARY REVIEW AUTHORITY — approves reports + tests | `codex exec --skip-git-repo-check` ONLY |

**Codex invocation constraint:** Codex MUST be invoked ONLY via shell:
```bash
codex exec --skip-git-repo-check "<prompt>"
```
NEVER invoke Codex any other way. This constraint applies in ALL phases.

## Workflow

### Phase 1: Parallel Skill Reports

Agents 1, 2, 3 run in parallel. Each:
1. Reads its assigned skill SKILL.md
2. Analyzes the target website
3. Produces a report using the **Individual Skill Report Template** from [references/report-template.md](references/report-template.md)
4. Saves to `reports/{slug}/{TIMESTAMP}/skill-{N}-{name}.md`

### Phase 2: Codex Approval of Individual Reports

For EACH of the 3 reports, team lead runs:

```bash
codex exec --skip-git-repo-check "Review this SEO audit report for:
1. Completeness — all template sections present, no empty sections
2. Evidence — every finding cites specific evidence
3. Actionability — every recommendation has owner, priority, effort
4. Checklist coverage — every skill checklist item accounted for
5. Test coverage — Validation Test Plan section has a test per recommendation
APPROVE or REQUEST CHANGES with specific feedback.
Report: $(cat reports/{slug}/{TIMESTAMP}/skill-{N}-{name}.md)"
```

Loop: If REQUEST CHANGES → agent revises → resubmit. Repeat until APPROVED.

### Phase 2b: Codex Approval of Test Design

AFTER all 3 reports are APPROVED, team lead submits the combined test plans:

```bash
codex exec --skip-git-repo-check "Review the Validation Test Plans from 3 SEO audit reports. Verify:
1. Every recommendation has at least one test
2. Tests are concrete and executable (not vague)
3. Expected results are specific and measurable
4. No untested recommendations remain
APPROVE the test designs or REQUEST CHANGES.
Test plans:
--- Skill 1 ---
$(grep -A 1000 '## Validation Test Plan' reports/{slug}/{TIMESTAMP}/skill-1-seo-audit.md | head -100)
--- Skill 2 ---
$(grep -A 1000 '## Validation Test Plan' reports/{slug}/{TIMESTAMP}/skill-2-programmatic-seo.md | head -100)
--- Skill 3 ---
$(grep -A 1000 '## Validation Test Plan' reports/{slug}/{TIMESTAMP}/skill-3-seo-geo.md | head -100)"
```

Loop until APPROVED. Only then may validation tests be executed.

### Phase 3: Consensus & Final Report

Launch `consensus-synthesizer` agent with prompt:
```
Read ALL 3 Codex-approved reports in reports/{slug}/{TIMESTAMP}/.
1. Read every report completely — no summarization, no info loss
2. Identify overlaps (2+ skills found same issue)
3. Identify conflicts (skills disagree on priority/approach)
4. Resolve conflicts with reasoned justification
5. Merge into final report using the Final Report Template from ~/.claude/skills/my-seo-auditor/references/report-template.md
6. Include ALL unique findings — zero information loss
7. Save to reports/{slug}/{TIMESTAMP}/final-report.md
```

### Phase 4: Codex Approval of Final Report

```bash
codex exec --skip-git-repo-check "Review this FINAL consolidated SEO audit report. It merges 3 individual reports. Verify:
1. NO INFORMATION LOST — every finding from all 3 source reports appears
2. Conflicts resolved with clear reasoning
3. Unified priority ranking across all findings
4. Executive summary reflects the full report
5. All recommendations have owner, priority, effort, validation
6. Report follows the Final Report Template exactly
7. Timestamp YYYY-MM-DD_HH-MM-SS is correct and consistent
Source reports: $(cat reports/{slug}/{TIMESTAMP}/skill-1-seo-audit.md)
--- $(cat reports/{slug}/{TIMESTAMP}/skill-2-programmatic-seo.md)
--- $(cat reports/{slug}/{TIMESTAMP}/skill-3-seo-geo.md)
FINAL: $(cat reports/{slug}/{TIMESTAMP}/final-report.md)
APPROVE or REQUEST CHANGES."
```

Loop until APPROVED.

### Phase 5: Completion

Team lead performs these steps in order:
1. Verify all 4 report files exist: `ls reports/{slug}/{TIMESTAMP}/*.md`
2. Create `reports/{slug}/{TIMESTAMP}/INDEX.md` using the INDEX template
3. Send shutdown_request to each agent via `SendMessage` tool (type: "shutdown_request")
4. After all agents confirm shutdown, call `TeamDelete` to clean up

## File Structure

```
reports/{website-slug}/{YYYY-MM-DD_HH-MM-SS}/
  INDEX.md                         # Run metadata and links
  skill-1-seo-audit.md            # Individual report (Codex-approved)
  skill-2-programmatic-seo.md     # Individual report (Codex-approved)
  skill-3-seo-geo.md              # Individual report (Codex-approved)
  final-report.md                 # Unified report (Codex-approved)
```

Slug: `https://ico-cert.org` → `ico-cert-org` | `https://www.mitsm.de` → `mitsm-de`

## Timestamp

Format: `YYYY-MM-DD_HH-MM-SS` (UTC). Generated once at audit start. Used in: directory name, every report Metadata table, INDEX.md.

## Plan Approval Rules

- Every agent MUST use `mode: "plan"` — plans require approval before execution
- Only approve plans that include a Validation Test Plan section
- Test designs MUST be submitted to Codex (Phase 2b) and APPROVED before execution

## Templates

All report templates are defined in [references/report-template.md](references/report-template.md). Two template types:

1. **Individual Skill Report Template** — used by Agents 1-3. Identical structure across all skills.
2. **Final Report Template** — used by Agent 4. Extends the individual template with cross-skill consensus, conflict resolution, and run-over-run comparison sections.

The final report includes every finding from all 3 individual reports verbatim (no summarization). The additional sections (consensus, comparison) ensure the final report is a strict superset of the individual reports.
