# Skill S11 – Test Harness Standard

## Goal

Provide a consistent approach to building and running tests across Bash scripts, PHP applications and APIs. This skill ensures that tests are easy to maintain and provide reliable feedback.

## When to Use

- When creating new test suites or expanding existing ones.
- When integrating tests into continuous integration pipelines.

## Checklist

- [ ] Choose a testing framework appropriate for the language (e.g. `bats` for Bash, `phpunit` for PHP, Postman or curl for APIs).
- [ ] Organise tests in a `tests/` directory with subfolders per technology (e.g. `tests/bash`, `tests/php`, `tests/api`).
- [ ] Use descriptive names for test files and functions.
- [ ] Mock or stub external dependencies to isolate the unit under test.
- [ ] Write negative tests to ensure proper error handling.
- [ ] Provide a test runner script (e.g. `./scripts/test.sh`) that executes all tests and reports a summary.
- [ ] Integrate the test runner in CI (e.g. GitHub Actions).
- [ ] Store fixtures and test data under `tests/fixtures`.
- [ ] Clean up any temporary files created during tests.
- [ ] Document how to run the tests in the README or in a test guide.

## Minimal Snippets

```
# Example bash test (bats)
@test "install script exits with 0" {
  run ./install.sh --dry-run
  [ "$status" -eq 0 ]
}
```

```
# Example PHP test (phpunit)
public function testHomePageReturns200(): void {
    $response = $this->get('/');
    $this->assertEquals(200, $response->getStatusCode());
}
```

## Success Criteria

- Tests can be executed with a single command.
- All critical paths have test coverage, including failure scenarios.
- Tests are reproducible across environments.
- CI fails if any test fails and passes when fixed.

## Common Failure Modes

- Tests depend on the state of external services without mocking.
- Tests leave behind artefacts or open connections.
- Lack of negative tests leads to unhandled errors in production.