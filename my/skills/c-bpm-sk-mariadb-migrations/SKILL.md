---
name: c-bpm-sk-mariadb-migrations
description: "MariaDB migration — database migration, alter table, add column, schema change, SQL migration. Forward-only migration pattern with safe schema changes."
paths: ['**/migrations/**']
enforcement: block
intentPatterns: "mariadb migration;;database migration;;alter table;;schema (change|migration);;add (column|index) (to|migration)"
user-invocable: false
---

# MariaDB Migrations

Forward-only migration pattern for MariaDB databases allowing schema changes to be applied safely across environments.

## Checklist

- [ ] Use migration tool (mysql CLI with numbered scripts) or PHP migration library
- [ ] Number migrations sequentially (`001_create_users_table.sql`, `002_add_index.sql`)
- [ ] Idempotent: check for existence before creating/altering
- [ ] Never drop column/table without backup and deprecation period
- [ ] Wrap data transformations in transactions when possible
- [ ] Provide rollback plan (even if migration is forward-only)
- [ ] Document purpose and impact of each migration in changelog

## Snippets

```sql
-- 003_add_email_column.sql
ALTER TABLE users
ADD COLUMN email VARCHAR(255) NOT NULL AFTER username;

-- 004_backfill_email.sql
UPDATE users SET email = CONCAT(username, '@example.com') WHERE email IS NULL;
```

## Success Criteria

- Migrations apply cleanly on both empty and pre-populated databases
- Database schema version is unambiguous
- Rollbacks possible up to a reasonable point

## Common Failure Modes

- Non-idempotent migrations causing repeated column additions
- Manual schema changes outside of migrations
- Lack of documentation during deployment

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
