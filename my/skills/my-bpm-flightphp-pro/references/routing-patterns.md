# Flight PHP Routing Patterns

## Table of Contents
- [Route Definitions](#route-definitions)
- [Named Parameters & Constraints](#named-parameters--constraints)
- [Route Groups](#route-groups)
- [Resource Routes](#resource-routes)
- [Middleware](#middleware)
- [Streaming Responses](#streaming-responses)
- [Route Aliasing & URL Generation](#route-aliasing--url-generation)

## Route Definitions

### Basic Routes

```php
// HTTP method routes
Flight::route('GET /users', [UserController::class, 'index']);
Flight::route('POST /users', [UserController::class, 'store']);
Flight::route('PUT /users/@id', [UserController::class, 'update']);
Flight::route('DELETE /users/@id', [UserController::class, 'destroy']);

// Multiple methods
Flight::route('GET|POST /form', [FormController::class, 'handle']);
```

### Callable Patterns

```php
// Controller class method (DI-resolved)
Flight::route('GET /users', [UserController::class, 'index']);

// Closure (simple routes only)
Flight::route('GET /health', function (): void {
    Flight::json(['status' => 'ok']);
});
```

## Named Parameters & Constraints

```php
// Basic named parameter
Flight::route('GET /users/@id', [UserController::class, 'show']);
// $id available as method parameter: public function show(int $id): void

// Regex constraint
Flight::route('GET /users/@id:[0-9]+', [UserController::class, 'show']);

// Multiple parameters
Flight::route('GET /posts/@year:[0-9]{4}/@month:[0-9]{2}', [PostController::class, 'archive']);

// Optional parameter (use ? suffix — Flight does NOT use brackets for optional segments)
Flight::route('GET /api/v@version:[0-9]?/users', [UserController::class, 'index']);

// Wildcard/splat
Flight::route('GET /docs/*', [DocController::class, 'show']);
// Access via Flight::request()->splat
```

## Route Groups

```php
Flight::group('/api/v1', function (): void {
    Flight::group('/users', function (): void {
        Flight::route('GET /', [UserController::class, 'index']);
        Flight::route('GET /@id:[0-9]+', [UserController::class, 'show']);
        Flight::route('POST /', [UserController::class, 'store']);
    });

    Flight::group('/posts', function (): void {
        Flight::route('GET /', [PostController::class, 'index']);
        Flight::route('GET /@id:[0-9]+', [PostController::class, 'show']);
    });
}, [new AuthMiddleware(), new RateLimitMiddleware()]);
```

## Resource Routes

RESTful CRUD route registration in one call:

```php
// Generates: GET /users, GET /users/@id, GET /users/create,
//            POST /users, GET /users/@id/edit, PUT /users/@id, DELETE /users/@id
Flight::resource('/users', UserController::class);

// Controller must implement these methods:
// index(), show(int $id), create(), store(), edit(int $id), update(int $id), destroy(int $id)

// With middleware
Flight::resource('/users', UserController::class, ['middleware' => [new AuthMiddleware()]]);
```

## Middleware

### Class-Based Middleware (Recommended)

```php
declare(strict_types=1);

namespace App\Middleware;

use flight\net\Request;
use flight\net\Response;

final class AuthMiddleware
{
    /**
     * Before hook — runs before the route handler.
     * Return false to halt execution.
     */
    public function before(Request $request, Response $response, array &$params): bool
    {
        $token = $request->getHeader('Authorization');

        if ($token === '' || !$this->validateToken($token)) {
            Flight::jsonHalt(['error' => 'Unauthorized'], 401);
            return false; // never reached due to halt, but explicit for clarity
        }

        return true;
    }

    /**
     * After hook — runs after the route handler.
     */
    public function after(Request $request, Response $response, array &$params): void
    {
        $response->header('X-Request-Id', bin2hex(random_bytes(16)));
    }

    private function validateToken(string $token): bool
    {
        // Token validation logic
        return true;
    }
}
```

### Applying Middleware

```php
// Single route
Flight::route('GET /admin', [AdminController::class, 'dashboard'])
    ->addMiddleware([new AuthMiddleware(), new AdminMiddleware()]);

// Route group
Flight::group('/api', function (): void {
    // routes...
}, [new AuthMiddleware(), new CorsMiddleware()]);

// Global middleware (wrap all routes in an empty group)
Flight::group('', function (): void {
    // All routes here...
}, [new SecurityHeadersMiddleware(), new CorsMiddleware()]);
```

### Middleware Execution Order

```
Request → Before (per route/group level) → Handler → After (per route/group level) → Response
```

## Streaming Responses

```php
Flight::route('GET /stream', function (): void {
    Flight::response()->header('Content-Type', 'text/event-stream');
    Flight::response()->header('Cache-Control', 'no-cache');

    Flight::response()->stream(function (int $chunkIndex): bool {
        echo "data: chunk {$chunkIndex}\n\n";
        flush();
        return $chunkIndex < 10; // return false to stop
    }, 1000); // 1-second delay between chunks
});
```

## Route Aliasing & URL Generation

```php
// Name a route with alias
Flight::route('GET /users/@id', [UserController::class, 'show'])->setAlias('user.show');

// Generate URL from alias
$url = Flight::getUrl('user.show', ['id' => 42]); // "/users/42"
```

## Complete REST API Example

```php
declare(strict_types=1);

// bootstrap.php or routes.php

Flight::group('/api/v1', function (): void {
    // Public routes
    Flight::route('POST /auth/login', [AuthController::class, 'login']);
    Flight::route('POST /auth/register', [AuthController::class, 'register']);

    // Protected routes
    Flight::group('', function (): void {
        Flight::resource('/users', UserController::class);
        Flight::resource('/posts', PostController::class);

        Flight::route('GET /me', [ProfileController::class, 'show']);
        Flight::route('PUT /me', [ProfileController::class, 'update']);
    }, [new AuthMiddleware()]);
}, [new CorsMiddleware(), new RateLimitMiddleware()]);
```
