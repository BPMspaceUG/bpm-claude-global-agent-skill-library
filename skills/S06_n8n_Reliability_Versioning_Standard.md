# Skill S06 – n8n Reliability & Versioning Standard

## Goal

Ensure that n8n workflows are reliable, maintainable and easy to version. This standard defines patterns for idempotency, error handling, export/import and environment separation.

## When to Use

- When creating or modifying n8n workflows.
- When exporting workflows for version control.
- When preparing workflows for deployment across environments.

## Checklist

- [ ] Assign a clear and descriptive name to each workflow and node.
- [ ] Use idempotency keys to prevent duplicate processing (e.g. store a unique reference in Redis or database).
- [ ] Implement error branches and fallback nodes; use the built‑in `error` output or custom logic.
- [ ] Configure retries with exponential backoff for transient failures.
- [ ] Separate DEV, TEST and PROD environments by using different credential sets and endpoints.
- [ ] Export workflows to JSON and store them in version control; avoid editing JSON by hand.
- [ ] Use the [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills) pack to extend node definitions and validate expressions.
- [ ] Document inputs, outputs and triggers for each workflow.

## Minimal Snippets

```
# Example idempotency pattern (pseudo-code)
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

- Workflows do not process the same event more than once.
- Failures trigger retries or notifications rather than silently failing.
- Workflow exports can be imported into another environment without modification.
- Environment separation ensures that test data does not pollute production.

## Common Failure Modes

- Hardcoding credentials or environment details in nodes.
- Lack of error handling leading to lost data.
- Unversioned workflows causing confusion when rolling back changes.