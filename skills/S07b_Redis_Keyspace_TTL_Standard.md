# Skill S07b – Redis Keyspace & TTL Standard

## Goal

Define conventions for Redis key names, TTL policies and patterns such as locks and queues to ensure predictable behaviour and avoid collisions or memory leaks.

## When to Use

- Whenever using Redis for caching, locking, rate limiting or queues.
- When integrating workflows that store transient state in Redis.

## Checklist

- [ ] Prefix all keys with an application and context namespace (e.g. `app:module:`).
- [ ] Use semantic segments separated by colons (e.g. `users:session:{id}`).
- [ ] Define a default TTL for each type of key; avoid setting keys without expiration unless absolutely necessary.
- [ ] Use `SET key value EX 3600 NX` for locks and ensure locks expire.
- [ ] Implement distributed locks with a safe pattern (e.g. using `SETNX` with expiry and verifying lock ownership).
- [ ] For queues, use Redis lists or streams and monitor queue length to prevent backlog.
- [ ] Document key patterns and TTLs in a central place.

## Minimal Snippets

```
# Acquire a lock
if redis-cli set "app:task:lock" 1 EX 60 NX; then
  # do work
  redis-cli del "app:task:lock"
fi
```

## Success Criteria

- Keys are discoverable and do not collide across different modules.
- TTLs prevent indefinite growth of memory usage.
- Locks prevent concurrent processing of critical sections.
- Queue processing keeps pace with job production.

## Common Failure Modes

- Generic key names that collide with other applications.
- Missing TTLs leading to memory bloat.
- Locks that are never released due to missing expiry or ownership checks.