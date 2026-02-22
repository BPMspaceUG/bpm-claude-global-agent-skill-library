# Team Orchestration Workflow for Flight PHP Projects

Full agent team orchestration workflow for building, refactoring, and improving Flight PHP projects with milestone-tracked parallel development and Codex-reviewed quality gates.

## Table of Contents

- [GitHub Issue Tracking Rules](#github-issue-tracking-rules)
- [Phase 0 — Discovery & Environment Scan](#phase-0--discovery--environment-scan)
- [Phase 1 — Repo Sync & Security](#phase-1--repo-sync--security)
- [Phase 2 — Analysis & Team Planning](#phase-2--analysis--team-planning)
- [Phase 3 — Spawn Agent Team](#phase-3--spawn-agent-team)
- [Phase 4 — Plan Approval (Dual Gate)](#phase-4--plan-approval-dual-gate)
- [Phase 5 — Test Design (Dual Gate)](#phase-5--test-design-dual-gate)
- [Phase 6 — Implementation](#phase-6--implementation)
- [Phase 7 — Testing & Verification](#phase-7--testing--verification)
- [Phase 8 — PR & Synthesis](#phase-8--pr--synthesis)
- [Codex Rules](#codex-rules)

---

## GitHub Issue Tracking Rules

### Issue Types

Only two issue types are used:

- **BUG** — Something is broken, insecure, or behaves incorrectly
- **FEATURE** — New functionality, refactoring, or improvement

No labels. No tags. Issue type is the only classifier.

### One Issue Per Improvement

Each discrete improvement, fix, or feature gets its own issue. All phases of work on that issue are documented as comments on the issue itself. No separate plan files, no external documents.

### Milestone-Based Lifecycle

**Read `my-team-milestones` skill** for full milestone definitions, transition rules, and Codex gate patterns.

Uses the FULL lifecycle: `new` -> `planned` -> `plan-approved` -> `test-designed` -> `test-design-approved` -> `implemented` -> `tested-success`/`tested-failed` -> `test-approved` -> `DONE` (human only).

---

## Phase 0 — Discovery & Environment Scan

Before any analysis or planning, establish the working environment.

### Create Lifecycle Milestones

Create all milestones via GitHub MCP if they don't already exist:

```
new, planned, plan-approved, test-designed, test-design-approved,
implemented, tested-success, tested-failed, test-approved, DONE
```

Skip any milestone that already exists in the repository.

### Check MCP Servers

- GitHub MCP is **required** — abort if unavailable
- Check for Context7 MCP (key-value store for shared state)
- Note any other available MCP servers

### Check Existing Skills and Agents

- List available skills — prefer specialized skills (e.g., `flightphp-pro`) over generic ones
- Check for existing agent configurations in `.claude/agents/`
- Note which skills teammates should load

### Read Project Context

- Read `CLAUDE.md` at project root for project-specific rules
- Read CI/CD configuration (GitHub Actions, etc.)
- Read coding conventions, linting config, PHPStan level
- Read `composer.json` for dependencies and autoloading
- Read project structure (controllers, services, repositories, middleware, views)

### Fetch Existing GitHub Issues

- List all open issues to understand current state
- Check for issues that overlap with planned work
- Note any blocked or stalled issues

---

## Phase 1 — Repo Sync & Security

### Sync Repository

```bash
git pull --rebase
git log --oneline -10   # Check recent changes
```

- Check for open PRs that might conflict with planned work
- Note the current branch and ensure you're on main/master

### Security Scan

Perform a comprehensive security audit:

1. **Hardcoded secrets** — Scan for API keys, passwords, tokens in source files
2. **Dependency audit** — Run `composer audit` to check for known vulnerabilities
3. **`.gitignore` check** — Ensure `.env`, vendor/, and sensitive files are excluded
4. **File permissions** — Check that no files have overly permissive modes (777, world-writable)
5. **SQL injection** — Scan for raw SQL string concatenation (should use SimplePdo with prepared statements)
6. **XSS vectors** — Check for unescaped output in templates

### Create BUG Issues for Security Findings

Every security finding gets its own BUG issue with:
- Clear description of the vulnerability
- File and line number(s) affected
- Suggested remediation
- Severity assessment (critical, high, medium, low)

---

## Phase 2 — Analysis & Team Planning

### Codebase Analysis

Analyze the codebase across these dimensions, with Flight PHP-specific focus:

| Dimension | What to Look For |
|-----------|-----------------|
| **Code Quality** | Strict types, final classes, readonly properties, proper typing, no suppressed errors |
| **Architecture** | Controller/Service/Repository pattern, DTOs, Value Objects, proper separation of concerns |
| **Flight Patterns** | Route groups, class-based middleware, DI container usage, event system, `Flight::jsonHalt()` for errors |
| **Security** | Input validation, CSRF protection, prepared statements, output escaping, security headers |
| **Performance** | N+1 queries, unnecessary loops, caching opportunities, lazy loading |
| **Testing** | PHPUnit coverage, isolated Engine instances, integration tests, edge cases |
| **Documentation** | PHPDoc blocks, README accuracy, API documentation |
| **Dependencies** | Composer packages up to date, unused dependencies, version constraints |

### Create and Link GitHub Issues

- Create one issue per identified improvement (BUG or FEATURE)
- Group issues by logical teammate assignment
- Set initial milestone to `new`

### Determine Team Size

- Minimum: 2 teammates (for small projects or focused work)
- Maximum: 6 teammates (for large refactoring efforts)
- **No overlapping files** — each file belongs to exactly one teammate's scope
- If two improvements touch the same file, assign them to the same teammate

### Present to User and WAIT

Present a summary to the user:

1. **Discovery findings** — project structure, tech stack, existing issues
2. **Security findings** — any BUG issues created
3. **Analysis results** — improvements identified, grouped by dimension
4. **Proposed team** — teammate names, responsibilities, assigned issues, file scopes
5. **Estimated complexity** — per teammate

**STOP and WAIT for user confirmation before proceeding.** Do not spawn any teammates until the user approves the plan.

---

## Phase 3 — Spawn Agent Team

### Model Policy

Choose the cheapest model that can handle the task:

| Model | When to Use |
|-------|------------|
| **Haiku** (default) | Single-file changes, straightforward refactoring, test writing, documentation |
| **Sonnet** | Complex multi-file changes, architectural refactoring, intricate logic |
| **Opus** | Only if both Haiku and Sonnet fail at the task |

Start with Haiku. Escalate only when needed.

### Teammate Naming

Use descriptive role-based names that reflect the teammate's responsibility:

- `route-refactorer` — Restructuring route definitions and groups
- `middleware-hardener` — Security middleware improvements
- `test-writer` — PHPUnit test coverage expansion
- `di-optimizer` — DI container and service layer improvements
- `controller-splitter` — Breaking large controllers into focused ones
- `dto-extractor` — Extracting DTOs and Value Objects from inline arrays

### Teammate Instructions

Each teammate receives:

1. **Scope** — Exactly which files and directories they own
2. **Boundaries** — Files they must NOT touch
3. **Issue numbers** — Which GitHub issues they are responsible for
4. **Deliverables** — What concrete output is expected
5. **MCP servers** — Which MCP servers are available
6. **Skills to load** — `flightphp-pro` skill must be loaded for Flight PHP context
7. **First action** — Submit a plan as an issue comment BEFORE any implementation

---

## Phase 4 — Plan Approval (Dual Gate)

### Teammate Submits Plan

The teammate posts a plan as a comment on their assigned issue(s). The plan must include:

- **Files to change** — List every file that will be created, modified, or deleted
- **Changes description** — What will change and why
- **Test coverage plan** — What tests will be written and what they verify
- **Risk assessment** — What could go wrong
- **Rollback strategy** — How to undo the changes if needed

### Dual Review

1. **Team Lead reviews** — Checks scope adherence, architectural fit, completeness
2. **Codex reviews** — Run:
   ```bash
   codex exec --skip-git-repo-check "Review this plan for issue #N in a Flight PHP project. Check for: scope creep, missing test coverage, architectural violations, security concerns. Plan: <plan content>"
   ```

### Approval Criteria

Both Team Lead AND Codex must approve. Move to milestone: `plan-approved`.

### Auto-Reject Conditions

Automatically reject the plan if:
- No test plan is included
- Files outside the teammate's assigned scope are listed
- No rollback strategy is provided
- The plan introduces patterns that violate Flight PHP conventions (e.g., closures for route handlers, business logic in controllers)

Post rejection reason as an issue comment. Teammate revises and resubmits.

---

## Phase 5 — Test Design (Dual Gate)

### Teammate Submits Test Design

The teammate posts a test design as a comment on their assigned issue(s). The design must include:

- **Test class names** — Following `*Test.php` naming convention
- **Test method names** — Descriptive, covering happy path and edge cases
- **Flight Engine setup** — How isolated Engine instances are configured for each test
- **Assertions** — What each test verifies
- **Mocking strategy** — What dependencies are mocked and how
- **Data providers** — For parameterized tests where applicable

### Example Test Structure for Flight PHP

```php
final class UserControllerTest extends TestCase
{
    private Engine $app;

    protected function setUp(): void
    {
        $this->app = new Engine();
        // Configure routes, DI container, middleware for isolated testing
    }

    public function testIndexReturnsJsonUserList(): void
    {
        // Arrange, Act, Assert with Flight Engine
    }
}
```

### Dual Review

1. **Team Lead reviews** — Checks coverage completeness, edge cases, isolation
2. **Codex reviews** — Run:
   ```bash
   codex exec --skip-git-repo-check "Review this PHPUnit test design for a Flight PHP project. Check for: adequate coverage, proper Engine isolation, missing edge cases, assertion quality. Test design: <test design content>"
   ```

### Approval

Both must approve. Move to milestone: `test-design-approved`.

---

## Phase 6 — Implementation

### Feature Branch

Each teammate works on their own feature branch:

```bash
git checkout -b refactor/<teammate-name>
```

### Development Rules

- **TDD preferred** — Write tests first, then implementation
- **Run existing tests** before and after changes — nothing may break
- **Follow Flight PHP conventions** — strict types, final classes, class-based middleware, controller/service/repo pattern
- **Load `flightphp-pro` skill** for Flight-specific guidance
- **Commit incrementally** with descriptive messages
- **Stay within assigned scope** — do not modify files outside your boundaries

### Milestone Update

When implementation is complete, move issue to milestone: `implemented`.

---

## Phase 7 — Testing & Verification

### Teammate Runs Tests

```bash
./vendor/bin/phpunit
./vendor/bin/phpstan analyse
./vendor/bin/php-cs-fixer fix --dry-run --diff
```

- All tests pass → milestone: `tested-success`
- Any test fails → milestone: `tested-failed`

### Failed Tests

If tests fail:
1. Document the failure as an issue comment (test name, error message, stack trace)
2. Set milestone to `tested-failed`
3. Fix the issue and re-run tests
4. When fixed, move back to `tested-success`

### Independent Verification

Team Lead and Codex independently verify:

1. **Team Lead** — Pulls the branch, runs tests, reviews code
2. **Codex** — Run:
   ```bash
   codex exec --skip-git-repo-check "Review this implementation for a Flight PHP project. Check: tests pass, code follows Flight conventions, no security issues, no breaking changes. Code diff: <diff content>"
   ```

Both must approve. Move to milestone: `test-approved`.

---

## Phase 8 — PR & Synthesis

### Create Pull Request

Create a PR that references all resolved issues:

```
Resolves #12, Resolves #13, Resolves #14
```

PR description includes:
- Summary of all changes
- List of issues resolved
- Test coverage summary
- Any migration or deployment notes

### Final Report

Present a synthesis report to the user:

1. **Discovery summary** — What was found during initial scan
2. **Changes made** — Per-teammate breakdown of modifications
3. **Test coverage** — New tests added, coverage metrics if available
4. **Issue numbers** — All issues created and their current milestones
5. **Remaining work** — Any issues deferred or requiring follow-up

### Human Sign-Off Required

- Do NOT merge the PR without explicit human confirmation
- Do NOT move any issues to `DONE` — only humans do that
- Present the PR URL and await instructions

---

## Codex Rules

Codex is the primary review authority for all Claude-generated code in this workflow.

### Invocation

Codex is invoked ONLY via:

```bash
codex exec --skip-git-repo-check "<review prompt>"
```

Never use interactive mode. Never skip Codex review at mandatory gates.

### Mandatory Review Gates

Codex review is required at exactly 3 gates:

1. **Plan approval** (Phase 4) — Reviews the implementation plan
2. **Test design approval** (Phase 5) — Reviews the test design
3. **Test verification** (Phase 7) — Reviews the implementation and test results

### If Codex Is Unavailable

If Codex cannot be reached or fails to respond:
- **STOP** all work at that gate
- **Notify the user** immediately
- **Do NOT proceed** without Codex review — the dual-gate requirement is non-negotiable

### Logging

All Codex responses must be logged as comments on the relevant GitHub issue. This creates an audit trail of all review decisions.
