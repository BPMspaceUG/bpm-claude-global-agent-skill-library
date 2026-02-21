---
model: opus
name: my-datatables
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
