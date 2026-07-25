---
name: c-bpm-sk-test-harness
description: "Test harness — write tests, create test suite, test coverage, CI testing, Bash/PHP/API tests. Consistent approach to building and running tests."
enforcement: block
intentPatterns: "test harness;;(write|create) (a )?(new )?test (suite|harness);;test coverage (setup|plan);;(bash|php|api) test (suite|framework)"
user-invocable: true
---

# Test Harness

Consistent approach to building and running tests across Bash scripts, PHP applications and APIs.

## Checklist

- [ ] Framework per language: `bats` (Bash), `phpunit` (PHP), curl/Postman (APIs)
- [ ] Tests in `tests/` with subfolders per tech (`tests/bash`, `tests/php`, `tests/api`)
- [ ] Descriptive names for test files and functions
- [ ] Mock/stub external dependencies for isolation
- [ ] Negative tests for error handling
- [ ] Test runner script (`./scripts/test.sh`) executing all tests
- [ ] CI integration (e.g. GitHub Actions)
- [ ] Fixtures under `tests/fixtures`
- [ ] Cleanup temporary files after tests
- [ ] Document how to run tests in README

## Snippets

```bash
# bats test
@test "install script exits with 0" {
  run ./install.sh --dry-run
  [ "$status" -eq 0 ]
}
```

```php
// phpunit test
public function testHomePageReturns200(): void {
    $response = $this->get('/');
    $this->assertEquals(200, $response->getStatusCode());
}
```

## Success Criteria

- All tests executable with a single command
- Critical paths covered including failure scenarios
- Tests reproducible across environments
- CI fails on test failure, passes when fixed

## Common Failure Modes

- Tests depending on external service state without mocking
- Tests leaving artefacts or open connections
- Missing negative tests causing unhandled production errors

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
