---
model: opus
name: c-bpm-sk-redis-keyspace
description: "Redis keyspace — Redis keys, caching strategy, TTL policy, distributed lock, rate limiting, Redis queue. Naming conventions and operational patterns."
enforcement: block
intentPatterns: "redis (keyspace|key naming);;redis (caching|ttl) (strategy|policy);;(distributed lock|rate limit).* redis;;redis (queue|stream) pattern"
user-invocable: false
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

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
