---
model: opus
name: my-bpm-redis-keyspace
description: Conventions for Redis key names, TTL policies, locks, and queues. Use when implementing caching, locking, rate limiting, or queues with Redis. Derived from S07b.
---

# Redis Keyspace & TTL

Conventions for Redis key names, TTL policies and patterns such as locks and queues to ensure predictable behaviour and avoid collisions or memory leaks.

## Checklist

- [ ] Prefix all keys with application and context namespace (`app:module:`)
- [ ] Semantic segments separated by colons (`users:session:{id}`)
- [ ] Default TTL for each key type; avoid keys without expiration unless necessary
- [ ] Locks: `SET key value EX 3600 NX` with verified ownership
- [ ] Distributed locks with `SETNX` + expiry + ownership verification
- [ ] Queues: Redis lists or streams with monitored queue length
- [ ] Document key patterns and TTLs centrally

## Snippets

```bash
# Acquire a lock
if redis-cli set "app:task:lock" 1 EX 60 NX; then
  # do work
  redis-cli del "app:task:lock"
fi
```

## Success Criteria

- Keys are discoverable and collision-free across modules
- TTLs prevent indefinite memory growth
- Locks prevent concurrent processing of critical sections
- Queue processing keeps pace with job production

## Common Failure Modes

- Generic key names that collide with other applications
- Missing TTLs leading to memory bloat
- Locks never released due to missing expiry or ownership checks
