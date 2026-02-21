---
model: opus
name: my-bpm-flightphp-pro
description: Senior PHP developer expertise for Flight PHP v3 micro-framework. Covers routing, middleware, DI containers, event system, templates, and API development with PHP 8.3+ strict typing, PSR compliance, and modern patterns. Includes agent team orchestration workflow for building and refactoring Flight PHP projects with Codex-reviewed, milestone-tracked parallel development. Use when building or maintaining Flight PHP applications, creating REST APIs with Flight, configuring Flight routing/middleware/DI, writing PHP code targeting the Flight framework, or orchestrating a team to build/refactor a Flight PHP project.
---

# Flight PHP Pro

Senior Flight PHP v3 engineer. PHP 8.3+ strict typing, PSR standards, enterprise patterns adapted for micro-framework architecture.

## Core Workflow

1. **Analyze** — Understand requirements, identify Flight components needed
2. **Design** — Choose patterns (controller/service/repo, DTOs, middleware)
3. **Implement** — Write strict-typed code using Flight APIs
4. **Secure** — Apply security middleware, validate input, escape output
5. **Test** — PHPUnit with isolated Engine instances

## Flight PHP Quick Reference

### Routing

```php
// Basic routes
Flight::route('GET /users', [UserController::class, 'index']);
Flight::route('POST /users', [UserController::class, 'store']);

// Named parameters with regex constraints
Flight::route('GET /users/@id:[0-9]+', [UserController::class, 'show']);

// Route groups with shared middleware
Flight::group('/api/v1', function (): void {
    Flight::route('GET /users', [UserController::class, 'index']);
    Flight::route('POST /users', [UserController::class, 'store']);
}, [new AuthMiddleware()]);

// Resource routes (RESTful CRUD in one call)
Flight::resource('/users', UserController::class);

// Route alias and URL generation
Flight::route('GET /users/@id', [UserController::class, 'show'])->setAlias('user.show');
$url = Flight::getUrl('user.show', ['id' => 42]); // "/users/42"
```

### Middleware (Class-Based)

```php
final class AuthMiddleware
{
    public function before(Request $request, Response $response, array &$params): bool
    {
        if (!$this->isAuthenticated($request)) {
            Flight::jsonHalt(['error' => 'Unauthorized'], 401);
            return false;
        }
        return true;
    }

    public function after(Request $request, Response $response, array &$params): void
    {
        $response->header('X-Request-Id', bin2hex(random_bytes(16)));
    }
}

// Apply to route
Flight::route('GET /admin', [AdminController::class, 'index'])
    ->addMiddleware([new AuthMiddleware()]);
```

Execution order: Route/Group Before → **Handler** → Route/Group After. For global middleware, use an empty group wrapping all routes.

### DI Container

```php
// flightphp/container (PSR-11, recommended)
// use flight\Container;
$container = new Container();
Flight::registerContainerHandler([$container, 'get']);

// Register services using set(), not register()
$container->set(SimplePdo::class, function () {
    return new SimplePdo($_ENV['DB_DSN'], $_ENV['DB_USER'], $_ENV['DB_PASS']);
});
$container->set(UserRepository::class);
$container->set(UserService::class);
$container->set(UserController::class);
// Constructor dependencies resolved automatically
```

### Request & Response

```php
// Request data
$request = Flight::request();
$request->url;              // Current URL
$request->method;           // HTTP method
$request->ip;               // Client IP
$request->data['field'];    // POST/PUT body data
$request->query['page'];    // Query string params
$request->getHeader('Authorization');
$request->getVar('key');    // Any superglobal

// JSON responses
Flight::json($data);                    // 200 JSON
Flight::json($data, 201);               // Custom status
Flight::jsonHalt(['error' => 'msg'], 400); // JSON + stop execution

// Other responses
Flight::redirect('/login');
Flight::render('template.latte', ['key' => 'value']);
Flight::halt(404, 'Not found');
```

### Events

```php
// Register listener
Flight::onEvent('user.created', function (array $user): void {
    // Send email, audit log, etc.
});

// Trigger event
Flight::triggerEvent('user.created', $newUser);
```

### Configuration & Extension

```php
// Config
Flight::set('flight.log_errors', true);
Flight::set('flight.views.path', __DIR__ . '/views');
Flight::set('app.name', 'MyApp');
$name = Flight::get('app.name');

// Map custom method
Flight::map('notFound', function (): void {
    Flight::json(['error' => 'Not found'], 404);
});

// Register component
Flight::register('cache', MemcachedCache::class, [], function ($cache): void {
    $cache->addServer('localhost', 11211);
});
$cache = Flight::cache(); // singleton access
```

## Constraints

### MUST DO
- `declare(strict_types=1);` in every PHP file
- Use `final` on classes not designed for extension
- Use `readonly` properties/classes for immutable data
- Use constructor promotion for DTOs and Value Objects
- Use prepared statements (SimplePdo) for ALL database queries
- Use class-based middleware (not closures) for non-trivial logic
- Use `Flight::jsonHalt()` for error responses in API routes
- Type all parameters, return types, and properties
- Follow PSR-4 autoloading, PER-CS 2.0 coding style
- Use enums for fixed sets of values (roles, statuses)
- Use `match` instead of `switch`
- Validate input at controller/DTO boundary

### MUST NOT DO
- No raw SQL string concatenation/interpolation — always bind parameters
- No `@` error suppression operator
- No `eval()`, `extract()`, or `compact()`
- No `global` variables
- No `mixed` type when a specific type is possible
- No business logic in controllers — delegate to services
- No direct `$_GET`, `$_POST`, `$_SERVER` — use `Flight::request()`
- No `echo`/`print` for responses — use `Flight::json()` or `Flight::render()`
- No closures for route handlers in production (use controller classes)
- No `var_dump`/`print_r` left in code

## Team Orchestration Mode

When invoked as team lead for a Flight PHP project, operate in DELEGATE MODE:
- Coordinate, review, and approve — do NOT implement directly
- Spawn 2-6 teammates with specific Flight PHP responsibilities
- All work tracked as GitHub Issues with milestone-based lifecycle
- Codex review mandatory at 3 gates: plan approval, test design approval, test verification

Workflow phases:
1. Discovery — scan repo, MCP servers, existing issues
2. Security — audit dependencies (`composer audit`), scan for secrets
3. Analysis — assess code quality, architecture, identify improvements
4. Team spawn — assign issues to teammates (default: haiku model)
5. Plan approval — dual gate (Team Lead + Codex)
6. Test design — dual gate (Team Lead + Codex)
7. Implementation — feature branches, TDD, no breakage
8. Verification — independent test verification
9. PR synthesis — create PR, report to user, await human sign-off

Read `references/team-orchestration.md` for the complete phased workflow, milestone definitions, Codex review commands, and team coordination rules.

## Reference Files

Load these as needed for detailed patterns and examples:

### `references/routing-patterns.md`
Read when: setting up routes, configuring route groups, implementing resource routes, adding middleware to routes, working with named parameters/regex constraints, streaming responses, or generating URLs from route aliases.

### `references/architecture-patterns.md`
Read when: structuring a new Flight project, implementing controllers with DI, setting up service/repository layers, creating DTOs or Value Objects, configuring the DI container, using the event system, or integrating Latte templates.

### `references/php-modern-practices.md`
Read when: using PHP 8.3+ features (enums, readonly, match, constructor promotion), configuring static analysis tools (PHPStan, PHP-CS-Fixer, Rector), setting up Composer, or reviewing PSR standards compliance.

### `references/security-testing.md`
Read when: implementing CSRF protection, XSS prevention, SQL injection prevention, security headers, CORS, rate limiting, input validation, or writing PHPUnit tests with Flight Engine instances.

### `references/team-orchestration.md`
Read when: orchestrating a team to build or refactor a Flight PHP project, setting up milestone-based issue tracking, spawning and coordinating agent teammates, running Codex review gates, or managing the full development lifecycle from discovery through PR synthesis.
