---
name: c-bpm-sk-php-crud-api-review
description: "php-crud-api review — evaluate php-crud-api, API integration review, mevdschee crud, auto-generated REST. Security review and integration guidance."
paths: ['**/php-crud-api/**']
enforcement: block
intentPatterns: "php-crud-api;;mevdschee crud;;auto.generated rest api;;review (the )?crud api"
user-invocable: true
---

# php-crud-api Review

Guidance for reviewing and integrating applications built with `mevdschee/php-crud-api`, which exposes a fully CRUD REST API for a database.

## Checklist

- [ ] Review schema; only expose required tables via `allowedTables`
- [ ] Primary keys properly defined on all tables
- [ ] Foreign keys declared for relationships (enables filtering/joins)
- [ ] Authentication configured (JWT or HTTP Basic)
- [ ] Filtering, pagination, sorting supported and documented
- [ ] CORS configured for browser-consumed APIs
- [ ] Disable/secure `/status` or metadata endpoints if not needed
- [ ] HTTPS for all endpoints
- [ ] Rate limiting or quotas enforced
- [ ] Document API base URL and deviations from defaults

## Snippets

```
GET /api.php/users?limit=10&filter=id,gt,100
```

## Success Criteria

- Only intended tables and columns are exposed
- Authentication is required and enforced
- Filtering and pagination work as expected
- Clients can use the API without reading the source

## Common Failure Modes

- Exposing entire databases without restrictions
- Missing primary keys causing misbehaviour
- No authentication leading to unauthorised access

## Findings → Issues

Every finding this skill surfaces — bug, optimization, gap, decision-needed,
even a maybe-not-OK hunch — is filed as a GitHub Issue **immediately**, one
issue per discrete finding, at the moment it is found. Never ask first;
over-filing is fine, asking is not. Dedup before filing: search open issues
and skip only on a genuine match (note "already tracked: #N"). Every created
issue gets milestone `new` and exactly one type label — `bug` or
`enhancement` (lowercase) — at creation; issue-write-gate enforces both
mechanically. The user decides afterwards which issues are kept or worked on.

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
