# Skill S07a – MariaDB Migrations Standard

## Goal

Provide a forward‑only migration pattern for MariaDB databases that allows schema changes to be applied safely across environments.

## When to Use

- When adding or altering tables, columns, indexes or constraints in MariaDB.
- When deploying changes that require data transformations.

## Checklist

- [ ] Use a migration tool (e.g. `mysql` CLI with numbered scripts) or a PHP migration library.
- [ ] Number migrations sequentially (e.g. `001_create_users_table.sql`, `002_add_index_to_orders.sql`).
- [ ] Write migrations to be idempotent; check for the existence of tables or columns before creating or altering.
- [ ] Never drop a column or table without explicit backup and a deprecation period.
- [ ] Wrap data transformations in transactions when possible.
- [ ] Provide a rollback plan in case deployment fails (even if the migration itself is forward‑only).
- [ ] Document the purpose and impact of each migration in a changelog.

## Minimal Snippets

```
-- 003_add_email_column.sql
ALTER TABLE users
ADD COLUMN email VARCHAR(255) NOT NULL AFTER username;

-- 004_backfill_email.sql
UPDATE users SET email = CONCAT(username, '@example.com') WHERE email IS NULL;
```

## Success Criteria

- Migrations apply cleanly on both empty and pre‑populated databases.
- Database schema version can be determined unambiguously.
- Rollbacks are possible up to a reasonable point (e.g. before irreversible data changes).

## Common Failure Modes

- Non‑idempotent migrations causing repeated addition of columns.
- Manual schema changes outside of migrations.
- Lack of documentation, leading to confusion during deployment.