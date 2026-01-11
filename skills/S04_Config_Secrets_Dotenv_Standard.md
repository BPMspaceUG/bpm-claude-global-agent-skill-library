# Skill S04 – Config & Secrets (Dotenv) Standard

## Goal

Ensure that configuration values and secrets are loaded safely and consistently across Bash, PHP and n8n workflows, and that sensitive data is not exposed inadvertently.

## When to Use

- When scripts or applications require configuration values such as API tokens, database credentials or endpoints.
- When reading environment variables and `.env` files in Bash or PHP.

## Checklist

- [ ] Use a `.env` file to store secrets and configuration that should not be committed to version control.
- [ ] Provide a `.env.example` file documenting the required variables without actual values.
- [ ] Set file permissions on `.env` files to `600` or more restrictive.
- [ ] In Bash, load `.env` variables with `set -o allexport; source .env; set +o allexport`, or use a helper function.
- [ ] In PHP, use a dotenv library or a simple loader to read `.env` into `$_ENV` or `$_SERVER`.
- [ ] In n8n, define credentials in the environment or via the credential manager; never hardcode values in nodes.
- [ ] Redact secrets in logs and error messages.
- [ ] Document precedence: environment variables override `.env` values.

## Minimal Snippets

```
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

```
# PHP dotenv loader (simple)
foreach (file('.env', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
    if (strpos(trim($line), '#') === 0) continue;
    list($name, $value) = explode('=', $line, 2);
    putenv("$name=$value");
}
```

## Success Criteria

- Secrets are not stored in source code.
- `.env` files are excluded by `.gitignore`.
- Applications load configuration reliably in all environments.
- Logs do not reveal sensitive values.

## Common Failure Modes

- Committing `.env` files or secrets to version control.
- Loading `.env` multiple times, causing unexpected overrides.
- Using weak file permissions, allowing other users to read secrets.