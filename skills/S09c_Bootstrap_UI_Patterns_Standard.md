# Skill S09c – Bootstrap UI Patterns Standard

## Goal

Provide guidance on building user interfaces with Bootstrap, focusing on consistent styling, responsiveness and accessibility.

## When to Use

- When creating modals, forms, alerts and other UI elements with Bootstrap.
- When designing pages that need to work across devices.

## Checklist

- [ ] Use the appropriate Bootstrap components (cards, modals, alerts, navbars) instead of custom styles.
- [ ] Follow a grid layout (`row` and `col-*` classes) to ensure responsive design.
- [ ] Apply consistent spacing with utility classes (e.g. `mt-3`, `p-2`).
- [ ] Use accessible components; ensure buttons have labels and links have discernible text.
- [ ] Use form validation classes (`is-invalid`, `invalid-feedback`) to show errors.
- [ ] Incorporate icons using a standard library (e.g. Font Awesome, Lucide).
- [ ] Avoid inline CSS; prefer utility and component classes.
- [ ] Test across breakpoints (`sm`, `md`, `lg`, `xl`).

## Minimal Snippets

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

- Interfaces are cohesive and match the look and feel of Bootstrap.
- Layouts adjust smoothly across screen sizes.
- Forms and controls are accessible and provide feedback.

## Common Failure Modes

- Mixing custom styles with Bootstrap causing conflicts.
- Ignoring accessibility attributes (aria labels, roles).
- Fixed widths or absolute positioning that break responsiveness.