---
model: opus
name: c-bpm-sk-php-crud-api-review
description: "php-crud-api review — evaluate php-crud-api, API integration review, mevdschee crud, auto-generated REST. Security review and integration guidance."
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
