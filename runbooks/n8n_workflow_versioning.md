# n8n Workflow Versioning Runbook

Use this runbook to manage versions of n8n workflows and deploy them across environments.

## Workflow Naming

- Use a descriptive name including the purpose and a version or date (e.g. `Sync CRM Contacts v1`, `Order Fulfilment 2026-01-11`).
- Avoid ambiguous names like `Untitled Workflow`.

## Exporting Workflows

1. In the n8n UI, open the workflow.
2. Use **Download** to export it as JSON.
3. Save the file under a versioned directory in your repository, e.g. `workflows/v1/sync-crm-contacts.json`.
4. Commit the exported file with a message describing changes.

## Importing Workflows

1. Ensure you are in the correct environment (DEV/TEST/PROD).
2. Use **Upload** or the n8n CLI to import the JSON file.
3. Assign the correct credentials and environment variables after import.

## Version Control

- Store all exported workflows under a `workflows/` directory with subfolders per version.
- Use semantic versioning or date‑based versioning consistently.
- Document changes in a `CHANGELOG.md` specific to workflows.

## Deployment

- Create automation scripts or a pipeline step that imports workflows into your target environment.
- For production, consider a manual approval step before activation.

## Rollback

- To roll back, import a previous version of the workflow and activate it.
- Ensure that any dependent services or triggers are updated accordingly.

## References

- Skill S06 – n8n Reliability & Versioning Standard