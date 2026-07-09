---
model: opus
name: c-bpm-sk-config-secrets
description: "Secrets management — .env files, API tokens, credentials, config management, secret handling. Safe configuration across Bash, PHP, and n8n."
enforcement: block
intentPatterns: "secrets? management;;manage .env (file|secret);;(api |)credential(s| ) (handling|management);;config(ure)? secrets"
user-invocable: false
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

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
