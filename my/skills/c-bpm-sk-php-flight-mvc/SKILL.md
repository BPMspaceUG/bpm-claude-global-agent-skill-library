---
model: opus
name: c-bpm-sk-php-flight-mvc
description: Conventions for PHP backend applications using Flight microframework in MVC style. Use when starting a new PHP service with Flight, refactoring to modular structure, or reviewing contributions. Basis skill — my-flightphp-pro is the extended version. Derived from S05.
---

# PHP Flight MVC

Conventions for building PHP backend applications using the Flight microframework in a Model-View-Controller style. Promotes separation of concerns, testability and maintainability.

## Checklist

- [ ] Project structure: `app/Controllers`, `app/Services`, `app/Repositories`, `config/`, `public/`, `vendor/`
- [ ] Flight initialization and routing in `bootstrap.php`
- [ ] Thin controllers: only orchestrate requests and responses
- [ ] Business logic in service classes; repositories handle DB access
- [ ] Dependency injection for services and repositories
- [ ] Central error handling with consistent API responses
- [ ] Configuration in `.env` and/or `config/`
- [ ] `composer.json` with PSR-4 autoloading
- [ ] Unit tests for services, functional tests for controllers

## Snippets

```php
// bootstrap.php
<?php
require 'vendor/autoload.php';
$flight = Flight::route('/', [HomeController::class, 'index']);
Flight::start();
```

```php
// app/Controllers/HomeController.php
class HomeController {
    private $service;
    public function __construct(HomeService $service) {
        $this->service = $service;
    }
    public function index() {
        $data = $this->service->getHomeData();
        Flight::json($data);
    }
}
```

## Success Criteria

- Controllers are readable, no business logic
- Services and repositories are unit-testable
- Configuration loaded from environment and config files
- PSR-compliant, maintainable by multiple developers

## Common Failure Modes

- Fat controllers mixing routing and business logic
- Tight coupling between controllers and database
- Lack of autoloading and PSR compliance

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
