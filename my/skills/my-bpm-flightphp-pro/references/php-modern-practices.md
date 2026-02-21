# PHP 8.3+ Modern Practices

## Table of Contents
- [PHP 8.x Features to Use](#php-8x-features-to-use)
- [Type System](#type-system)
- [PSR Standards](#psr-standards)
- [Static Analysis & Tooling](#static-analysis--tooling)
- [Composer Best Practices](#composer-best-practices)

## PHP 8.x Features to Use

### Constructor Promotion (8.0+)

```php
// DO: promoted readonly properties
final readonly class UserDto
{
    public function __construct(
        public string $name,
        public string $email,
        public int $age,
    ) {}
}

// DON'T: manual assignment
class UserDto {
    public string $name;
    public function __construct(string $name) {
        $this->name = $name; // unnecessary boilerplate
    }
}
```

### Readonly Properties & Classes (8.1/8.2+)

```php
// Entire class readonly (8.2+)
final readonly class Money
{
    public function __construct(
        public int $amount,
        public string $currency,
    ) {}
}

// Individual readonly properties (8.1+)
final class Config
{
    public function __construct(
        private readonly string $dbDsn,
        private readonly int $cacheTimeout,
    ) {}
}
```

### Enums (8.1+)

```php
enum UserRole: string
{
    case Admin = 'admin';
    case Editor = 'editor';
    case Viewer = 'viewer';

    public function canEdit(): bool
    {
        return match ($this) {
            self::Admin, self::Editor => true,
            self::Viewer => false,
        };
    }
}

// Usage
$role = UserRole::from($request->data['role']);
if ($role->canEdit()) { /* ... */ }
```

### Match Expression (8.0+)

```php
// DO: match (strict, expression, exhaustive)
$statusCode = match ($status) {
    'active' => 200,
    'pending' => 202,
    'deleted' => 410,
    default => 500,
};

// DON'T: switch with loose comparison
switch ($status) {
    case 'active': $statusCode = 200; break;
    // ...
}
```

### Named Arguments (8.0+)

```php
// Improves readability for functions with many params
$pdo = new SimplePdo(
    dsn: $_ENV['DB_DSN'],
    user: $_ENV['DB_USER'],
    pass: $_ENV['DB_PASS'],
);
```

### Nullsafe Operator (8.0+)

```php
// DO
$city = $user?->getAddress()?->getCity();

// DON'T
$city = $user !== null && $user->getAddress() !== null
    ? $user->getAddress()->getCity()
    : null;
```

### Fibers (8.1+)

Rarely needed directly — used internally by async libraries. Avoid unless building framework-level code.

### Typed Class Constants (8.3+)

```php
final class ApiConfig
{
    public const int MAX_RETRIES = 3;
    public const string BASE_URL = 'https://api.example.com';
    public const float TIMEOUT = 30.0;
}
```

### #[\Override] Attribute (8.3+)

```php
class BaseController
{
    public function beforeAction(): void {}
}

class UserController extends BaseController
{
    #[\Override]
    public function beforeAction(): void
    {
        // Compile-time check: parent method must exist
    }
}
```

### json_validate() (8.3+)

```php
// DO: validate before decode
if (json_validate($input)) {
    $data = json_decode($input, true, 512, JSON_THROW_ON_ERROR);
}

// DON'T: decode and check for null
$data = json_decode($input, true);
if ($data === null) { /* might be valid null JSON */ }
```

## Type System

### Strict Types Declaration

Every PHP file MUST start with:

```php
declare(strict_types=1);
```

### Type Declarations

```php
// Union types (8.0+)
function findUser(int|string $identifier): ?array { }

// Intersection types (8.1+)
function process(Countable&Iterator $collection): void { }

// DNF types (8.2+) — Disjunctive Normal Form
function handle((Countable&Iterator)|null $input): void { }

// never return type (8.1+)
function abort(string $message): never
{
    Flight::jsonHalt(['error' => $message], 500);
    // @phpstan-ignore-next-line (unreachable after halt)
    exit;
}

// true, false, null standalone types (8.2+)
function isValid(): true { return true; }
```

### PHPDoc for Arrays

```php
/** @var array<string, mixed> */
private array $config;

/** @return list<array{id: int, name: string}> */
public function getAll(): array { }

/** @param array<int, string> $ids */
public function findMany(array $ids): array { }
```

## PSR Standards

| PSR | Name | Usage |
|-----|------|-------|
| PSR-1 | Basic Coding Standard | Class naming, file structure |
| PSR-4 | Autoloading | Namespace-to-directory mapping via Composer |
| PER-CS 2.0 | Coding Style (replaces PSR-2/PSR-12) | Formatting, braces, spacing |
| PSR-7 | HTTP Message Interface | Not used by Flight (Flight has own Request/Response) |
| PSR-11 | Container Interface | flightphp/container implements this |
| PSR-3 | Logger Interface | Use Monolog or similar PSR-3 logger |
| PSR-15 | HTTP Handlers/Middleware | Not used by Flight (Flight has own middleware) |

### Key PER-CS 2.0 Rules

- Opening brace on same line for classes, methods, control structures
- One blank line before return in multi-line methods
- Use `final` on classes not designed for extension
- Trailing comma in multi-line parameter/argument lists
- No closing `?>` tag

## Static Analysis & Tooling

### PHPStan (Level 9+)

```yaml
# phpstan.neon
parameters:
    level: 9
    paths:
        - app
    tmpDir: storage/cache/phpstan
    checkGenericClassInNonGenericObjectType: false
```

### PHP-CS-Fixer

```php
// .php-cs-fixer.dist.php
return (new PhpCsFixer\Config())
    ->setRules([
        '@PER-CS2.0' => true,
        'strict_param' => true,
        'declare_strict_types' => true,
        'no_unused_imports' => true,
        'ordered_imports' => ['sort_algorithm' => 'alpha'],
        'trailing_comma_in_multiline' => true,
        'global_namespace_import' => [
            'import_classes' => true,
            'import_functions' => false,
            'import_constants' => false,
        ],
    ])
    ->setFinder(
        PhpCsFixer\Finder::create()->in(__DIR__ . '/app')
    );
```

### Rector

```php
// rector.php
use Rector\Config\RectorConfig;

return RectorConfig::configure()
    ->withPaths([__DIR__ . '/app'])
    ->withPhpSets(php83: true)
    ->withPreparedSets(deadCode: true, typeDeclarations: true);
```

### Composer Scripts

```json
{
    "scripts": {
        "lint": "php-cs-fixer fix --dry-run --diff",
        "fix": "php-cs-fixer fix",
        "analyse": "phpstan analyse",
        "test": "phpunit --testdox",
        "check": ["@lint", "@analyse", "@test"]
    }
}
```

## Composer Best Practices

- Always use `composer.lock` in version control for applications
- Use `^` version constraints for libraries: `"flightphp/core": "^3.0"`
- Separate `require` (production) from `require-dev` (dev tools)
- Use PSR-4 autoloading exclusively
- Run `composer audit` regularly for vulnerability checks

```json
{
    "require": {
        "php": ">=8.3",
        "flightphp/core": "^3.0",
        "flightphp/container": "^1.0",
        "latte/latte": "^3.0",
        "vlucas/phpdotenv": "^5.6"
    },
    "require-dev": {
        "phpunit/phpunit": "^11.0",
        "phpstan/phpstan": "^2.0",
        "friendsofphp/php-cs-fixer": "^3.0",
        "rector/rector": "^2.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/"
        }
    }
}
```
