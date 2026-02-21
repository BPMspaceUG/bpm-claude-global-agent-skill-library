# Flight PHP Architecture Patterns

## Table of Contents
- [Project Structure](#project-structure)
- [Controllers](#controllers)
- [Service Layer & Repository Pattern](#service-layer--repository-pattern)
- [DTOs and Value Objects](#dtos-and-value-objects)
- [DI Container Setup](#di-container-setup)
- [Event System](#event-system)
- [Template Engine Integration](#template-engine-integration)

## Project Structure

```
project/
├── app/
│   ├── Controllers/        # Route handlers
│   ├── Services/           # Business logic
│   ├── Repositories/       # Data access
│   ├── Middleware/          # Before/after filters
│   ├── DTOs/               # Data transfer objects
│   ├── ValueObjects/       # Immutable domain types
│   ├── Events/             # Event listeners
│   └── Views/              # Latte templates (.latte)
├── config/
│   ├── container.php       # DI container definitions
│   ├── routes.php          # Route definitions
│   ├── middleware.php       # Global middleware
│   └── events.php          # Event registrations
├── public/
│   └── index.php           # Entry point
├── tests/
│   ├── Unit/
│   └── Integration/
├── vendor/
├── composer.json
└── .env
```

## Controllers

Controllers handle HTTP concerns only — delegate business logic to services.

```php
declare(strict_types=1);

namespace App\Controllers;

use App\DTOs\CreateUserDto;
use App\Services\UserService;
use flight\Engine;

final class UserController
{
    public function __construct(
        private readonly UserService $userService,
        private readonly Engine $app,
    ) {}

    public function index(): void
    {
        $page = (int) ($this->app->request()->query['page'] ?? 1);
        $users = $this->userService->paginate($page);
        $this->app->json($users);
    }

    public function show(int $id): void
    {
        $user = $this->userService->findOrFail($id);
        $this->app->json($user);
    }

    public function store(): void
    {
        $dto = CreateUserDto::fromRequest($this->app->request());
        $user = $this->userService->create($dto);
        $this->app->json($user, 201);
    }

    public function update(int $id): void
    {
        $data = $this->app->request()->data->getData();
        $user = $this->userService->update($id, $data);
        $this->app->json($user);
    }

    public function destroy(int $id): void
    {
        $this->userService->delete($id);
        $this->app->json(null, 204);
    }
}
```

## Service Layer & Repository Pattern

### Service

```php
declare(strict_types=1);

namespace App\Services;

use App\DTOs\CreateUserDto;
use App\Repositories\UserRepository;

final class UserService
{
    public function __construct(
        private readonly UserRepository $userRepo,
    ) {}

    /**
     * @return array<string, mixed>
     */
    public function findOrFail(int $id): array
    {
        $user = $this->userRepo->findById($id);

        if ($user === null) {
            Flight::jsonHalt(['error' => 'User not found'], 404);
        }

        return $user;
    }

    /**
     * @return array<string, mixed>
     */
    public function create(CreateUserDto $dto): array
    {
        // Business logic, validation, etc.
        $passwordHash = password_hash($dto->password, PASSWORD_ARGON2ID);

        return $this->userRepo->insert([
            'name' => $dto->name,
            'email' => $dto->email,
            'password' => $passwordHash,
        ]);
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    public function update(int $id, array $data): array
    {
        $this->findOrFail($id);
        return $this->userRepo->update($id, $data);
    }

    public function delete(int $id): void
    {
        $this->findOrFail($id);
        $this->userRepo->delete($id);
    }

    /**
     * @return array{data: list<array<string, mixed>>, page: int, total: int}
     */
    public function paginate(int $page, int $perPage = 20): array
    {
        return $this->userRepo->paginate($page, $perPage);
    }
}
```

### Repository

```php
declare(strict_types=1);

namespace App\Repositories;

use flight\database\SimplePdo;

final class UserRepository
{
    public function __construct(
        private readonly SimplePdo $db,
    ) {}

    /**
     * @return array<string, mixed>|null
     */
    public function findById(int $id): ?array
    {
        $stmt = $this->db->runQuery(
            'SELECT id, name, email, created_at FROM users WHERE id = ?',
            [$id]
        );
        $row = $stmt->fetch();
        return $row !== false ? $row : null;
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    public function insert(array $data): array
    {
        $this->db->runQuery(
            'INSERT INTO users (name, email, password) VALUES (?, ?, ?)',
            [$data['name'], $data['email'], $data['password']]
        );
        $id = (int) $this->db->lastInsertId();
        return $this->findById($id);
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    public function update(int $id, array $data): array
    {
        $sets = [];
        $values = [];
        foreach ($data as $key => $value) {
            $sets[] = "{$key} = ?";
            $values[] = $value;
        }
        $values[] = $id;
        $this->db->runQuery(
            'UPDATE users SET ' . implode(', ', $sets) . ' WHERE id = ?',
            $values
        );
        return $this->findById($id);
    }

    public function delete(int $id): void
    {
        $this->db->runQuery('DELETE FROM users WHERE id = ?', [$id]);
    }

    /**
     * @return array{data: list<array<string, mixed>>, page: int, total: int}
     */
    public function paginate(int $page, int $perPage = 20): array
    {
        $offset = ($page - 1) * $perPage;
        $stmt = $this->db->runQuery(
            'SELECT id, name, email, created_at FROM users LIMIT ? OFFSET ?',
            [$perPage, $offset]
        );
        $total = (int) $this->db->fetchField('SELECT COUNT(*) FROM users');
        return [
            'data' => $stmt->fetchAll(),
            'page' => $page,
            'total' => $total,
        ];
    }
}
```

## DTOs and Value Objects

### DTO (Data Transfer Object)

```php
declare(strict_types=1);

namespace App\DTOs;

use flight\net\Request;

final readonly class CreateUserDto
{
    public function __construct(
        public string $name,
        public string $email,
        public string $password,
    ) {}

    public static function fromRequest(Request $request): self
    {
        $data = $request->data;

        $name = trim((string) ($data['name'] ?? ''));
        $email = trim((string) ($data['email'] ?? ''));
        $password = (string) ($data['password'] ?? '');

        if ($name === '' || $email === '' || $password === '') {
            Flight::jsonHalt(['error' => 'name, email, and password are required'], 422);
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Flight::jsonHalt(['error' => 'Invalid email format'], 422);
        }

        return new self($name, $email, $password);
    }
}
```

### Value Object

```php
declare(strict_types=1);

namespace App\ValueObjects;

final readonly class Email
{
    private function __construct(
        public string $value,
    ) {}

    public static function from(string $email): self
    {
        $email = trim($email);

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException("Invalid email: {$email}");
        }

        return new self(strtolower($email));
    }

    public function equals(self $other): bool
    {
        return $this->value === $other->value;
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
```

## DI Container Setup

### Using flightphp/container (PSR-11, recommended)

```php
// config/container.php
declare(strict_types=1);

use App\Controllers\UserController;
use App\Repositories\UserRepository;
use App\Services\UserService;
use flight\Container;
use flight\database\SimplePdo;

// Register the container handler
// use flight\Container;
$container = new Container();
Flight::registerContainerHandler([$container, 'get']);

// Database — singleton by default in flightphp/container
$container->set(SimplePdo::class, function () {
    return new SimplePdo(
        dsn: $_ENV['DB_DSN'],
        user: $_ENV['DB_USER'],
        pass: $_ENV['DB_PASS'],
    );
});

// Repository
$container->set(UserRepository::class);

// Service
$container->set(UserService::class);

// Controller — Engine injected automatically when type-hinted
$container->set(UserController::class);
```

### Using Dice (Alternative)

```php
use Dice\Dice;

$dice = new Dice();
Flight::registerContainerHandler(function (string $class, array $params) use ($dice) {
    return $dice->create($class, $params);
});

// Dice rules
$dice = $dice->addRules([
    SimplePdo::class => [
        'shared' => true,
        'constructParams' => [$_ENV['DB_DSN'], $_ENV['DB_USER'], $_ENV['DB_PASS']],
    ],
]);
```

## Event System

```php
// config/events.php
declare(strict_types=1);

use App\Events\AuditLogger;

// Register event listeners
Flight::onEvent('user.created', function (array $user): void {
    // Send welcome email, log audit trail, etc.
    AuditLogger::log('user.created', $user);
});

Flight::onEvent('user.deleted', function (int $userId): void {
    AuditLogger::log('user.deleted', ['id' => $userId]);
});

// Trigger events from services
// $this->userRepo->insert($data);
// Flight::triggerEvent('user.created', $user);
```

## Template Engine Integration

### Latte (Recommended)

```php
// config/container.php
use Latte\Engine as LatteEngine;

$container->set(LatteEngine::class, function () {
    $latte = new LatteEngine();
    $latte->setTempDirectory(__DIR__ . '/../storage/cache/latte');
    $latte->setAutoRefresh($_ENV['APP_ENV'] === 'development');
    return $latte;
});

// Register Latte as Flight's view engine
Flight::register('latte', LatteEngine::class, [], function (LatteEngine $latte): void {
    $latte->setTempDirectory(__DIR__ . '/../storage/cache/latte');
});

// Usage in controller
Flight::render('users/index.latte', ['users' => $users]);
```

### Entry Point

```php
// public/index.php
declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

// Load environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

// Bootstrap
require __DIR__ . '/../config/container.php';
require __DIR__ . '/../config/middleware.php';
require __DIR__ . '/../config/events.php';
require __DIR__ . '/../config/routes.php';

Flight::start();
```
