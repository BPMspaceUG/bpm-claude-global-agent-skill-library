# Skill S09a – DataTables Standard

## Goal

Standardise the use of the DataTables.net library for presenting and interacting with tabular data, ensuring consistent behaviour, accessibility and performance.

## When to Use

- When building front‑end pages that display tabular data.
- When integrating server‑side processing with DataTables.

## Checklist

- [ ] Use server‑side processing for large datasets; configure `ajax` with a proper endpoint.
- [ ] Escape and sanitise all cell values to prevent XSS.
- [ ] Enable pagination, sorting and searching; disable features that are not required.
- [ ] Define column renderers (`render` callbacks) for formatting dates, currency and status badges.
- [ ] Provide internationalisation via the `language` option.
- [ ] Preserve table state across page reloads with the `stateSave` option.
- [ ] Ensure the table is responsive or use a responsive plugin if necessary.
- [ ] Test keyboard navigation and screen reader support.

## Minimal Snippets

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
  language: {
    url: '/i18n/datatables-de.json'
  },
  stateSave: true
});
```

## Success Criteria

- Tables load quickly and handle large datasets gracefully.
- Users can sort, filter and navigate tables easily.
- The table is accessible to keyboard and screen reader users.

## Common Failure Modes

- Loading all data client‑side, causing performance issues.
- Failing to escape HTML content, leading to XSS vulnerabilities.
- Inconsistent column ordering or missing keys in data sources.