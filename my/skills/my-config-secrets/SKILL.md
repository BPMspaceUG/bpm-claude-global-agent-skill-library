---
name: my-config-secrets
description: Safe configuration and secrets management via .env files across Bash, PHP, and n8n. Use when scripts or applications require API tokens, database credentials, or other sensitive configuration. Derived from S04.
---

# Config & Secrets (Dotenv)

Ensure configuration values and secrets are loaded safely and consistently across Bash, PHP and n8n workflows, without inadvertent exposure.

## Checklist

- [ ] Use `.env` file for secrets (not committed to VCS)
- [ ] Provide `.env.example` with required variables (no values)
- [ ] File permissions on `.env`: `600` or more restrictive
- [ ] Bash: `set -o allexport; source .env; set +o allexport` or helper
- [ ] PHP: dotenv library or simple loader into `$_ENV`
- [ ] n8n: credentials via environment or credential manager, never in nodes
- [ ] Redact secrets in logs and error messages
- [ ] Document precedence: env vars override `.env` values

## Snippets

```bash
# Bash dotenv loader
dotenv() {
  local dotenv_file="${1:-.env}"
  [ -f "$dotenv_file" ] || return 1
  set -a
  . "$dotenv_file"
  set +a
}
dotenv ".env"
```

```php
// PHP dotenv loader (simple)
foreach (file('.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
    if (strpos(trim($line), '#') === 0) continue;
    list($name, $value) = explode('=', $line, 2);
    putenv("$name=$value");
}
```

## Success Criteria

- Secrets are not stored in source code
- `.env` files are excluded by `.gitignore`
- Applications load configuration reliably in all environments

## Common Failure Modes

- Committing `.env` to version control
- Loading `.env` multiple times causing overrides
- Weak file permissions allowing other users to read secrets
