---
model: opus
name: my-api-contract
description: Rules for designing and consuming RESTful APIs consistently with predictable endpoints, filtering, pagination, and error handling. Use when designing HTTP endpoints, integrating with APIs, or reviewing API behaviour. Derived from S08a.
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
