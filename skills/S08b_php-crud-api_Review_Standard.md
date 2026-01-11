# Skill S08b – php‑crud‑api Review Standard

## Goal

Provide guidance for reviewing and integrating applications built with `mevdschee/php-crud-api`, which exposes a fully CRUD REST API for a database.

## When to Use

- When evaluating whether php‑crud‑api is appropriate for a project.
- When integrating php‑crud‑api endpoints into workflows or frontend code.
- When performing security and compliance reviews of php‑crud‑api deployment.

## Checklist

- [ ] Review the database schema and ensure only required tables are exposed; use the `allowedTables` option to whitelist resources.
- [ ] Ensure that primary keys are properly defined on all tables; php‑crud‑api relies on them.
- [ ] Verify that foreign keys are declared for relationships; this enables filtering and joins.
- [ ] Configure authentication (e.g. JWT or HTTP Basic) to restrict access.
- [ ] Validate that filtering, pagination and sorting parameters are supported and documented.
- [ ] Ensure CORS is configured if the API is consumed from browsers.
- [ ] Disable or secure the open `/status` or metadata endpoints if not needed.
- [ ] Use HTTPS for all endpoints.
- [ ] Check that rate limiting or quotas are enforced to prevent abuse.
- [ ] Document the API base URL and any deviations from defaults.

## Minimal Snippets

```
GET /api.php/users?limit=10&filter=id,gt,100
```

## Success Criteria

- Only intended tables and columns are exposed.
- Authentication is required and enforced.
- Filtering and pagination work as expected.
- Clients understand how to use the API without reading the source.

## Common Failure Modes

- Exposing entire databases without restrictions.
- Missing primary keys causing php‑crud‑api to misbehave.
- No authentication on the API leading to unauthorised access.