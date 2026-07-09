---
model: opus
name: c-bpm-sk-n8n-reliability
description: "n8n workflow patterns — create n8n workflow, reliable workflow, version n8n, export workflow, multi-env deploy. Maintainable and versionable n8n workflows."
enforcement: block
intentPatterns: "n8n workflow;;(create|build|design) n8n;;version n8n workflow;;n8n (reliability|export|deploy)"
user-invocable: false
---

# n8n Reliability & Versioning

Ensure n8n workflows are reliable, maintainable and easy to version with patterns for idempotency, error handling, export/import and environment separation.

## Checklist

- [ ] Clear, descriptive names for each workflow and node
- [ ] Idempotency keys to prevent duplicate processing (store reference in Redis/DB)
- [ ] Error branches and fallback nodes with built-in `error` output or custom logic
- [ ] Retries with exponential backoff for transient failures
- [ ] Separate DEV/TEST/PROD environments with different credential sets
- [ ] Export workflows to JSON, store in version control; never edit JSON by hand
- [ ] Use n8n-skills pack for extended node definitions and expression validation
- [ ] Document inputs, outputs, and triggers for each workflow

## Idempotency Pattern

```json
{
  "name": "Process Order",
  "nodes": [
    {
      "type": "Function",
      "parameters": {
        "functionCode": "if (existsInDb(item.orderId)) { return []; } else { markAsProcessed(item.orderId); return items; }"
      }
    }
  ]
}
```

## Success Criteria

- Workflows do not process the same event more than once
- Failures trigger retries or notifications, not silent failure
- Exports can be imported into another environment without modification
- Test data does not pollute production

## Common Failure Modes

- Hardcoded credentials or environment details in nodes
- Lack of error handling leading to lost data
- Unversioned workflows causing rollback confusion

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
