# Database Migration Playbook

This playbook describes how to apply database schema changes safely using the MariaDB Migrations Standard.

## Running Migrations

1. Navigate to the directory containing migration scripts (e.g. `database/migrations/`).
2. Identify the highest migration number applied to the database. You can store this in a table such as `schema_migrations`.
3. Execute each new migration script in order:

```bash
mysql -u your_user -p your_database < 001_create_users_table.sql
mysql -u your_user -p your_database < 002_add_index_to_orders.sql
...
```

Alternatively, use a migration tool that automatically tracks and runs migrations (e.g. Phinx, Laravel Artisan).

## Creating a New Migration

1. Determine the next migration number (increment the last migration).
2. Create a new `.sql` file with a descriptive name, e.g. `003_add_email_column.sql`.
3. Write idempotent SQL statements; check for existence before altering.
4. Document the purpose of the migration at the top of the file.
5. Commit the migration script to version control and update the changelog.

## Best Practices

- Always test migrations on a copy of the production database.
- Use transactions where supported; wrap multiple statements in a single transaction to ensure atomicity.
- Avoid destructive operations (DROP TABLE, ALTER COLUMN) unless necessary; deprecate first.
- Keep migrations small and focused.

## Rollback

If a migration fails:

- Identify the last successful migration and restore the database from backup if needed.
- Fix the migration script and reapply from the failed migration.
- Avoid manual changes outside of migration scripts.

## References

- Skill S07a – MariaDB Migrations Standard