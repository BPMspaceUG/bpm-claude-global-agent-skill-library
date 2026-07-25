---
name: c-bpm-sk-api-contract
description: "API design rules — REST API contract, endpoint design, pagination, error handling, API review. Predictable endpoints, filtering, and consistent error responses."
enforcement: block
intentPatterns: "api (contract|design) review;;design.*(rest|api) (contract|endpoint);;api (endpoint|pagination|error) (design|pattern)"
user-invocable: false
---

# Generic API Contract

Rules for designing and consuming RESTful APIs consistently, ensuring predictable endpoints, filtering, pagination and error handling.

## Checklist

- [ ] Nouns for resource names, pluralised (`/users`, `/orders`)
- [ ] HTTP methods: GET (retrieve), POST (create), PUT/PATCH (update), DELETE (delete)
- [ ] Pagination via `limit`/`offset` or cursor-based for list endpoints
- [ ] Filtering and sorting via query parameters (`filter[status]=active`, `sort=-created_at`)
- [ ] Standard HTTP status codes with error messages in response body
- [ ] Consistent date/time formats (ISO 8601)
- [ ] Authentication and authorisation where applicable
- [ ] Document each endpoint with parameters, responses, error codes
- [ ] Version via URL path (`/v1/...`) or Accept headers

## Snippets

```
GET /orders?filter[status]=shipped&limit=10&offset=0

HTTP/1.1 200 OK
{
  "data": [
    { "id": 123, "status": "shipped" }
  ],
  "meta": {
    "total": 42,
    "limit": 10,
    "offset": 0
  }
}
```

## Success Criteria

- Clients can predict and consume APIs without reading the code
- APIs are versioned with communicated changes
- Filtering and pagination handled consistently
- Error responses are machine-readable with human-readable messages

## Common Failure Modes

- Mixing verbs in endpoint names (`/getUsers` instead of `/users`)
- Lack of pagination causing huge responses
- Unstructured error messages
- Breaking changes without versioning

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
