# Skill S05 – PHP Flight MVC Standard

## Goal

Define conventions for building PHP backend applications using the Flight microframework in a Model‑View‑Controller (MVC) style. This standard promotes separation of concerns, testability and maintainability.

## When to Use

- When starting a new PHP service using Flight.
- When refactoring an existing monolithic script into a modular structure.
- When reviewing contributions to ensure consistency.

## Checklist

- [ ] Structure the project with directories: `app/Controllers`, `app/Services`, `app/Repositories`, `config/`, `public/`, `vendor/`.
- [ ] Initialise Flight and set up routing in a dedicated `bootstrap.php`.
- [ ] Keep controllers thin: they should only orchestrate requests and responses.
- [ ] Place business logic in service classes; repositories handle database access.
- [ ] Use dependency injection to pass services and repositories into controllers.
- [ ] Handle errors centrally and return consistent API responses.
- [ ] Store configuration in `.env` and/or `config/`.
- [ ] Provide a `composer.json` defining dependencies and PSR‑4 autoloading.
- [ ] Write unit tests for services and functional tests for controllers.

## Minimal Snippets

```
# bootstrap.php
<?php
require 'vendor/autoload.php';
$flight = Flight::route('/', [HomeController::class, 'index']);
Flight::start();
```

```
# app/Controllers/HomeController.php
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

- Controllers are readable and do not contain business logic.
- Services and repositories are unit-testable.
- Application configuration is loaded from environment and config files.
- The codebase follows PSR standards and can be maintained by multiple developers.

## Common Failure Modes

- Fat controllers mixing routing and business logic.
- Tight coupling between controllers and database functions.
- Lack of autoloading and PSR compliance.