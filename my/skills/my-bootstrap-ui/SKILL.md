---
name: my-bootstrap-ui
description: Guidance for building UIs with Bootstrap focusing on consistent styling, responsiveness, and accessibility. Use when creating modals, forms, alerts, and responsive layouts with Bootstrap. Derived from S09c.
---

# Bootstrap UI Patterns

Guidance for building user interfaces with Bootstrap, focusing on consistent styling, responsiveness and accessibility.

## Checklist

- [ ] Use Bootstrap components (cards, modals, alerts, navbars) instead of custom styles
- [ ] Grid layout (`row` and `col-*` classes) for responsive design
- [ ] Consistent spacing with utility classes (`mt-3`, `p-2`)
- [ ] Accessible components: buttons have labels, links have discernible text
- [ ] Form validation classes (`is-invalid`, `invalid-feedback`) for errors
- [ ] Icons via standard library (Font Awesome, Lucide)
- [ ] No inline CSS; prefer utility and component classes
- [ ] Test across breakpoints (`sm`, `md`, `lg`, `xl`)

## Snippets

```html
<div class="modal fade" id="editModal" tabindex="-1" aria-labelledby="editModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <div class="modal-content rounded-2xl shadow">
      <div class="modal-header">
        <h5 class="modal-title" id="editModalLabel">Edit Item</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body">
        <form id="editForm">
          <div class="mb-3">
            <label for="name" class="form-label">Name</label>
            <input type="text" class="form-control" id="name" required>
            <div class="invalid-feedback">Name is required</div>
          </div>
          <button type="submit" class="btn btn-primary">Save</button>
        </form>
      </div>
    </div>
  </div>
</div>
```

## Success Criteria

- Interfaces match Bootstrap look and feel
- Layouts adjust smoothly across screen sizes
- Forms and controls are accessible with feedback

## Common Failure Modes

- Mixing custom styles with Bootstrap causing conflicts
- Ignoring accessibility attributes (aria labels, roles)
- Fixed widths or absolute positioning breaking responsiveness
