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
