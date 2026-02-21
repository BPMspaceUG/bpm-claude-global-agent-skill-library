---
model: opus
name: my-bpm-php-flight-mvc
description: Conventions for PHP backend applications using Flight microframework in MVC style. Use when starting a new PHP service with Flight, refactoring to modular structure, or reviewing contributions. Basis skill — my-bpm-flightphp-pro is the extended version. Derived from S05.
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
