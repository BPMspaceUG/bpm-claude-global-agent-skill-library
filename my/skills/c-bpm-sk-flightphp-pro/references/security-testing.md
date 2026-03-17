# Security & Testing for Flight PHP

## Table of Contents
- [CSRF Protection](#csrf-protection)
- [XSS Prevention](#xss-prevention)
- [SQL Injection Prevention](#sql-injection-prevention)
- [Security Headers Middleware](#security-headers-middleware)
- [CORS Middleware](#cors-middleware)
- [Rate Limiting](#rate-limiting)
- [Input Validation](#input-validation)
- [PHPUnit Testing](#phpunit-testing)

## CSRF Protection

### CSRF Middleware

```php
declare(strict_types=1);

namespace App\Middleware;

use flight\net\Request;
use flight\net\Response;

final class CsrfMiddleware
{
    public function before(Request $request, Response $response, array &$params): bool
    {
        if (in_array($request->method, ['GET', 'HEAD', 'OPTIONS'], true)) {
            return true;
        }

        $sessionToken = $_SESSION['csrf_token'] ?? '';
        $requestToken = $request->data['_csrf_token']
            ?? $request->getHeader('X-CSRF-Token')
            ?? '';

        if (!hash_equals($sessionToken, $requestToken)) {
            Flight::jsonHalt(['error' => 'CSRF token mismatch'], 403);
            return false;
        }

        return true;
    }
}

// Generate token (call at session start)
function generateCsrfToken(): string
{
    $token = bin2hex(random_bytes(32));
    $_SESSION['csrf_token'] = $token;
    return $token;
}
```

## XSS Prevention

### Latte Auto-Escaping (Recommended)

Latte escapes all output by default — no manual escaping needed:

```latte
{* Auto-escaped — safe *}
<p>{$user->name}</p>

{* Raw output — use ONLY for trusted HTML *}
{$trustedHtml|noescape}
```

### Manual Escaping (Non-Latte)

```php
// Always escape for HTML context
htmlspecialchars($input, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

// For JSON embedded in HTML
<script>const data = {$jsonData|noescape};</script>
// Ensure $jsonData is json_encode() output with JSON_HEX_TAG
```

## SQL Injection Prevention

### Always Use Prepared Statements

```php
// DO: SimplePdo with parameter binding
$stmt = $this->db->runQuery(
    'SELECT * FROM users WHERE email = ? AND status = ?',
    [$email, $status]
);

// DO: Named parameters
$stmt = $this->db->runQuery(
    'SELECT * FROM users WHERE email = :email',
    ['email' => $email]
);

// NEVER: String concatenation/interpolation
$this->db->runQuery("SELECT * FROM users WHERE email = '$email'"); // VULNERABLE
```

### Dynamic Column Names

```php
// Whitelist allowed columns — never interpolate user input
private const array SORTABLE_COLUMNS = ['name', 'email', 'created_at'];

public function findSorted(string $column, string $direction): array
{
    if (!in_array($column, self::SORTABLE_COLUMNS, true)) {
        throw new \InvalidArgumentException("Invalid sort column: {$column}");
    }
    $dir = strtoupper($direction) === 'DESC' ? 'DESC' : 'ASC';

    return $this->db->runQuery(
        "SELECT * FROM users ORDER BY {$column} {$dir}"
    )->fetchAll();
}
```

## Security Headers Middleware

```php
declare(strict_types=1);

namespace App\Middleware;

use flight\net\Request;
use flight\net\Response;

final class SecurityHeadersMiddleware
{
    public function after(Request $request, Response $response, array &$params): void
    {
        $response->header('X-Content-Type-Options', 'nosniff');
        $response->header('X-Frame-Options', 'DENY');
        $response->header('X-XSS-Protection', '0'); // modern browsers use CSP
        $response->header('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
        $response->header(
            'Content-Security-Policy',
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
        );
        $response->header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    }
}
```

## CORS Middleware

```php
declare(strict_types=1);

namespace App\Middleware;

use flight\net\Request;
use flight\net\Response;

final class CorsMiddleware
{
    /** @var list<string> */
    private const array ALLOWED_ORIGINS = [
        'https://app.example.com',
        'https://admin.example.com',
    ];

    public function before(Request $request, Response $response, array &$params): bool
    {
        $origin = $request->getHeader('Origin');

        if ($origin !== '' && in_array($origin, self::ALLOWED_ORIGINS, true)) {
            $response->header('Access-Control-Allow-Origin', $origin);
            $response->header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
            $response->header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-CSRF-Token');
            $response->header('Access-Control-Max-Age', '86400');
            $response->header('Vary', 'Origin');
        }

        // Handle preflight
        if ($request->method === 'OPTIONS') {
            $response->status(204);
            $response->send();
            return false;
        }

        return true;
    }
}
```

## Rate Limiting

### Simple In-Memory (per-process, development)

```php
declare(strict_types=1);

namespace App\Middleware;

use flight\net\Request;
use flight\net\Response;

final class RateLimitMiddleware
{
    private const int MAX_REQUESTS = 60;
    private const int WINDOW_SECONDS = 60;

    public function before(Request $request, Response $response, array &$params): bool
    {
        $ip = $request->ip;
        $key = "rate_limit:{$ip}";

        // Use Redis/APCu in production — this is a pattern example
        $redis = Flight::get('redis');
        $current = (int) $redis->incr($key);

        if ($current === 1) {
            $redis->expire($key, self::WINDOW_SECONDS);
        }

        $response->header('X-RateLimit-Limit', (string) self::MAX_REQUESTS);
        $response->header('X-RateLimit-Remaining', (string) max(0, self::MAX_REQUESTS - $current));

        if ($current > self::MAX_REQUESTS) {
            Flight::jsonHalt(['error' => 'Too many requests'], 429);
            return false;
        }

        return true;
    }
}
```

## Input Validation

```php
declare(strict_types=1);

namespace App\Services;

final class Validator
{
    /**
     * @param array<string, mixed> $data
     * @param array<string, string> $rules  e.g. ['email' => 'required|email', 'name' => 'required|min:2']
     * @return array<string, string> errors keyed by field
     */
    public static function validate(array $data, array $rules): array
    {
        $errors = [];

        foreach ($rules as $field => $ruleString) {
            $value = $data[$field] ?? null;

            foreach (explode('|', $ruleString) as $rule) {
                $error = match (true) {
                    $rule === 'required' && ($value === null || $value === '') => "{$field} is required",
                    $rule === 'email' && !filter_var($value, FILTER_VALIDATE_EMAIL) => "{$field} must be a valid email",
                    str_starts_with($rule, 'min:') => self::checkMin($field, $value, $rule),
                    str_starts_with($rule, 'max:') => self::checkMax($field, $value, $rule),
                    $rule === 'integer' && !is_numeric($value) => "{$field} must be an integer",
                    default => null,
                };

                if ($error !== null) {
                    $errors[$field] = $error;
                    break; // first error per field
                }
            }
        }

        return $errors;
    }

    private static function checkMin(string $field, mixed $value, string $rule): ?string
    {
        $min = (int) substr($rule, 4);
        return is_string($value) && mb_strlen($value) < $min
            ? "{$field} must be at least {$min} characters"
            : null;
    }

    private static function checkMax(string $field, mixed $value, string $rule): ?string
    {
        $max = (int) substr($rule, 4);
        return is_string($value) && mb_strlen($value) > $max
            ? "{$field} must be at most {$max} characters"
            : null;
    }
}
```

## PHPUnit Testing

### Testing with Flight Engine Instances

Flight provides `Engine` instances for isolated testing — avoid testing against the static `Flight::` facade.

```php
declare(strict_types=1);

namespace Tests\Integration;

use App\Controllers\UserController;
use App\Services\UserService;
use flight\Engine;
use PHPUnit\Framework\TestCase;

final class UserControllerTest extends TestCase
{
    private Engine $app;

    protected function setUp(): void
    {
        $this->app = new Engine();
        // Register routes, DI, etc. on this isolated instance
    }

    public function testIndexReturnsUsers(): void
    {
        $this->app->route('GET /users', [UserController::class, 'index']);
        $this->app->request()->url = '/users';
        $this->app->request()->method = 'GET';

        ob_start();
        $this->app->start();
        $output = ob_get_clean();

        $data = json_decode($output, true, 512, JSON_THROW_ON_ERROR);
        self::assertIsArray($data);
    }
}
```

### Unit Testing Services with Mocks

```php
declare(strict_types=1);

namespace Tests\Unit;

use App\DTOs\CreateUserDto;
use App\Repositories\UserRepository;
use App\Services\UserService;
use PHPUnit\Framework\TestCase;

final class UserServiceTest extends TestCase
{
    public function testCreateUserHashesPassword(): void
    {
        $repo = $this->createMock(UserRepository::class);
        $repo->expects(self::once())
            ->method('insert')
            ->with(self::callback(function (array $data): bool {
                // Password must be hashed, not plaintext
                return password_verify('secret123', $data['password']);
            }))
            ->willReturn(['id' => 1, 'name' => 'John', 'email' => 'john@example.com']);

        $service = new UserService($repo);
        $dto = new CreateUserDto('John', 'john@example.com', 'secret123');
        $result = $service->create($dto);

        self::assertSame(1, $result['id']);
    }
}
```

### Test Directory Structure

```
tests/
├── Unit/
│   ├── Services/
│   │   └── UserServiceTest.php
│   ├── DTOs/
│   │   └── CreateUserDtoTest.php
│   └── ValueObjects/
│       └── EmailTest.php
├── Integration/
│   ├── Controllers/
│   │   └── UserControllerTest.php
│   └── Repositories/
│       └── UserRepositoryTest.php
└── phpunit.xml
```

### phpunit.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
    bootstrap="vendor/autoload.php"
    colors="true"
    testdox="true"
    strict="true"
>
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>app</directory>
        </include>
    </source>
</phpunit>
```
