---
model: opus
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
