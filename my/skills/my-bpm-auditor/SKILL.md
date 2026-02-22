---
name: my-bpm-auditor
description: "Full repository audit with team-based parallel analysis. Triggers: 'audit this repo', 'review this codebase', 'full report on project', 'check code quality/security/performance', due diligence, maintenance handover. Produces [REPONAME]-YYMMDD-HHSS.md report. No issues created."
user-invocable: true
---

# /my-auditor - Repository Audit Skill

Comprehensive, team-based audit of an existing repository. Produces a single Markdown report — no GitHub issues created.

## When to Use

- "Audit this repo"
- "Review this codebase"
- "Give me a full report on this project"
- "Check code quality, security, performance"
- Before taking over maintenance of a codebase
- Due diligence on third-party code

## Output

A single Markdown file: `[REPONAME]-YYMMDD-HHSS.md` in the repo root.

**NO GitHub issues are created. Report only.**

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   AUDIT LEAD (you)                   │
│              Coordinates team, writes report          │
└──────────┬──────────┬──────────┬──────────┬─────────┘
           │          │          │          │
     ┌─────▼──┐ ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
     │ scout  │ │ aegis  │ │profiler│ │ critic │   ... up to 10
     │        │ │        │ │        │ │        │
     └────────┘ └────────┘ └────────┘ └────────┘
     Codebase   Security   Performance  Patterns
     Discovery  Audit      Analysis     & Quality
```

**Minimum 2, maximum 10 teammates. All use Opus 4.6 (inherit, never haiku).**

## Audit Phases

### Phase 1: Understand the Codebase

**Teammates:** scout (codebase explorer), general-purpose (tech stack analyzer)

1. Map directory structure and file tree (`tldr tree .`, `tldr structure .`)
2. Detect tech stack (languages, frameworks, dependencies)
3. Identify entry points, architecture patterns (`tldr arch .`)
4. Read README, CLAUDE.md, CONTRIBUTING.md, config files
5. Map dependency graph
6. Count lines of code by language

**Codex review after Phase 1:** See `references/codex-prompts.md`

### Phase 2: Check Patterns

**Teammates:** critic (code quality), aegis (security), profiler (performance), general-purpose (migrations + deployments)

#### 2a. Code Patterns & Quality
- Naming conventions, error handling, logging, dead code (`tldr dead .`), duplication, dependency freshness

#### 2b. Deployment Patterns
- CI/CD config, build scripts, environment management, IaC

#### 2c. Database & Migrations
- Migration sequencing, schema safety, query patterns (N+1, raw SQL), connection config

#### 2d. Performance
- Caching, async patterns, resource-heavy ops, bundle size, query efficiency

#### 2e. Security
- OWASP Top 10, secret detection, input validation, auth/authz, dependency vulns, headers, injection protection

**Tools:** `tldr diagnostics .`, `tldr dead .`, `tldr impact <func>`, `/qlty-check`, `/security` patterns, Grep for anti-patterns

**Codex review after Phase 2:** See `references/codex-prompts.md`

### Phase 3: Test Plan

**Teammate:** general-purpose (test planner)

1. Find and assess existing tests
2. Identify untested critical paths
3. Recommend specific tests that should exist
4. Provide verification commands
5. Run existing tests if safe (read-only, no side effects)

**Tools:** `tldr change-impact`, Glob for test discovery, Bash for safe test execution

**Codex review after Phase 3:** See `references/codex-prompts.md`

### Phase 4: Codex Final Review

**CRITICAL: Codex is the PRIMARY REVIEW authority.**

Run final Codex review on the complete assembled findings. See `references/codex-prompts.md` for the exact prompt.

Codex plays devil's advocate: challenges false positives, flags missed issues, disputes severity ratings, checks actionability of recommendations.

### Phase 5: Report Generation

Compile all findings + Codex challenges into the report. Use template from `references/report-template.md`.

Output file: `[REPONAME]-YYMMDD-HHSS.md` in repo root.

## Team Execution Protocol

### Step 1: Create Team
```
TeamCreate: "audit-[reponame]"
```

### Step 2: Spawn Teammates (min 2, max 10 based on repo size)

| Teammate | Agent Type | Phase | Role |
|----------|-----------|-------|------|
| scout-1 | scout | 1 | Codebase structure & architecture |
| stack-analyzer | general-purpose | 1 | Tech stack & dependencies |
| critic-1 | critic | 2 | Code quality & patterns |
| aegis-1 | aegis | 2 | Security audit |
| profiler-1 | profiler | 2 | Performance analysis |
| migration-checker | general-purpose | 2 | Database & migration review |
| deploy-checker | general-purpose | 2 | CI/CD & deployment review |
| test-planner | general-purpose | 3 | Test plan creation |

### Step 3: Coordinate
- Phase 1 teammates run in parallel → Codex review
- Phase 2 teammates run in parallel (after Phase 1) → Codex review
- Phase 3 runs after Phase 2 → Codex review
- Phase 4 final Codex review on assembled report
- Phase 5 write report → shutdown team

### Step 4: Write Report & Shutdown
Write `[REPONAME]-YYMMDD-HHSS.md`, send shutdown_request to all teammates, TeamDelete.

## Delegated Skills

| Skill | Used In | Purpose |
|-------|---------|---------|
| `/security` | Phase 2e | OWASP, secrets, auth patterns |
| `/qlty-check` | Phase 2a | Code quality metrics |
| `/explore` | Phase 1 | Codebase discovery |
| `/tldr-code` | Phase 1-3 | Token-efficient code analysis |
| `my-appsec-threatlite` | Phase 2e | Threat modeling |
| `my-test-harness` | Phase 3 | Test execution patterns |

## References

- `references/report-template.md` — Full report Markdown template
- `references/codex-prompts.md` — Per-phase Codex devil's advocate prompts

## Constraints

### MUST
- Produce exactly one `.md` report file
- Run Codex devil's advocate after EACH phase (not just at the end)
- Spawn at minimum 2 teammates, maximum 10
- Use Opus 4.6 for all teammates (inherit, never haiku)
- Include severity ratings for all findings
- Run existing tests if safe to do so
- Invoke Codex ONLY via: `codex exec --skip-git-repo-check [PROMPT]`

### MUST NOT
- Create GitHub issues (report only)
- Push code or create branches
- Modify any repository files (read-only audit)
- Skip the Codex devil's advocate review
- Make claims without reading actual files (see claim-verification rule)
- Use haiku model for any teammate

### ON BLOCKERS
- If unable to detect tech stack → ask user
- If tests require credentials/DB → note as "unable to verify" in report
- If repo is too large for single pass → ask user to scope the audit
- If Codex is unavailable → note in report, proceed without
