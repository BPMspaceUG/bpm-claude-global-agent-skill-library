# Skill S08a – Generic API Contract Standard

## Goal

Provide a set of rules for designing and consuming RESTful APIs consistently. This standard applies to any HTTP API, ensuring predictable endpoints, filtering, pagination and error handling.

## When to Use

- When designing new HTTP endpoints.
- When integrating with third‑party APIs.
- When reviewing or testing API behaviour.

## Checklist

- [ ] Use nouns for resource names and pluralise (e.g. `/users`, `/orders`).
- [ ] Use HTTP methods correctly: GET for retrieval, POST for creation, PUT/PATCH for updates, DELETE for deletion.
- [ ] Implement pagination using `limit` and `offset` or cursor‑based mechanisms for list endpoints.
- [ ] Support filtering and sorting via query parameters (e.g. `filter[status]=active`, `sort=-created_at`).
- [ ] Return standard HTTP status codes and include error messages in the response body.
- [ ] Use consistent date and time formats (ISO 8601).
- [ ] Require authentication and authorisation where applicable.
- [ ] Document each endpoint with its parameters, responses and error codes.
- [ ] Version APIs via URL path (`/v1/...`) or Accept headers.

## Minimal Snippets

```
# Example list endpoint
GET /orders?filter[status]=shipped&limit=10&offset=0

HTTP/1.1 200 OK
{
  "data": [
    { "id": 123, "status": "shipped", ... }
  ],
  "meta": {
    "total": 42,
    "limit": 10,
    "offset": 0
  }
}
```

## Success Criteria

- Clients can predict and consume APIs without reading the code.
- APIs are versioned and changes are communicated.
- Filtering and pagination are handled consistently.
- Error responses are machine readable and include human‑readable messages.

## Common Failure Modes

- Mixing verbs in endpoint names (e.g. `/getUsers` instead of `/users`).
- Lack of pagination leading to huge responses.
- Unstructured error messages.
- Breaking changes introduced without versioning.