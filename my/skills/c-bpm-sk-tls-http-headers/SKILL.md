---
model: opus
name: c-bpm-sk-tls-http-headers
description: "TLS and HTTP headers — SSL config, security headers, reverse proxy, HTTPS setup, XSS protection, clickjacking. Baseline TLS and header configuration."
enforcement: block
intentPatterns: "tls (config|setup);;(security|http) headers;;https (setup|config);;ssl (config|certificate);;(xss|clickjacking) (protection|header)"
user-invocable: false
---

# TLS & HTTP Headers

Baseline for configuring TLS and HTTP security headers to protect web applications against common attack vectors.

## Checklist

- [ ] TLS 1.2+ with weak ciphers disabled
- [ ] Certificates from trusted CA (e.g. Let's Encrypt) with automatic renewal
- [ ] HSTS with appropriate max-age and includeSubDomains
- [ ] Content Security Policy (CSP) whitelisting trusted sources
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY` or `SAMEORIGIN`
- [ ] `Referrer-Policy` header
- [ ] `Permissions-Policy` header limiting browser features
- [ ] CORS policies configured; avoid wildcard `*`
- [ ] Test with Mozilla Observatory or SSL Labs

## Snippets

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' cdn.example.com";
add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options DENY;
add_header Referrer-Policy no-referrer;
add_header Permissions-Policy "geolocation=(), microphone=()";
```

## Success Criteria

- A rating on SSL/TLS tests
- Security headers present with sensible values
- Browsers enforce secure connections
- Certificates renew automatically

## Common Failure Modes

- Default TLS settings with insecure ciphers
- Overly permissive or missing CSP
- Failing to renew certificates
- Wildcard CORS without restrictions

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
