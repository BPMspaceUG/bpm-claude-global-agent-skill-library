---
model: opus
name: c-bpm-sk-datatables
description: Standardised DataTables.net usage for tabular data with server-side processing, accessibility, and performance. Use when building front-end pages with tabular data or integrating server-side DataTables. Derived from S09a.
---

# DataTables

Standardise the use of DataTables.net for presenting and interacting with tabular data, ensuring consistent behaviour, accessibility and performance.

## Checklist

- [ ] Server-side processing for large datasets; configure `ajax` endpoint
- [ ] Escape and sanitise all cell values to prevent XSS
- [ ] Enable pagination, sorting, and searching; disable unused features
- [ ] Column renderers (`render` callbacks) for dates, currency, badges
- [ ] Internationalisation via `language` option
- [ ] `stateSave` for preserving state across reloads
- [ ] Responsive table or responsive plugin
- [ ] Test keyboard navigation and screen reader support

## Snippets

```javascript
$('#users-table').DataTable({
  serverSide: true,
  ajax: '/api/users/datatable',
  columns: [
    { data: 'id' },
    { data: 'name' },
    { data: 'email' },
    { data: 'created_at', render: data => new Date(data).toLocaleDateString() }
  ],
  language: { url: '/i18n/datatables-de.json' },
  stateSave: true
});
```

## Success Criteria

- Tables load quickly and handle large datasets
- Users can sort, filter, and navigate easily
- Accessible to keyboard and screen reader users

## Common Failure Modes

- Loading all data client-side causing performance issues
- Failing to escape HTML causing XSS
- Inconsistent column ordering or missing keys

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
