---
model: opus
name: c-bpm-sk-mariadb-migrations
description: "MariaDB migration — database migration, alter table, add column, schema change, SQL migration. Forward-only migration pattern with safe schema changes."
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
