---
model: opus
name: my-jquery-ajax-forms
description: Patterns for safe jQuery form submissions and AJAX requests with CSRF protection, error handling, and user feedback. Use when submitting forms without page reload or performing async UI updates. Derived from S09b.
---

# jQuery AJAX & Forms

Patterns for handling forms and AJAX requests with jQuery safely and maintainably, including error handling, CSRF protection and user feedback.

## Checklist

- [ ] Include CSRF token in AJAX headers or payloads
- [ ] Use `$.ajax` with success and error callbacks; handle HTTP errors explicitly
- [ ] Display loading indicators during pending requests
- [ ] Provide feedback on success (flash messages, modal updates)
- [ ] Validate inputs both client-side and server-side
- [ ] Prevent double submissions by disabling submit button
- [ ] Escape user content before DOM insertion
- [ ] Event delegation for dynamically created elements

## Snippets

```javascript
$('#myForm').on('submit', function(e) {
  e.preventDefault();
  const $btn = $(this).find('button[type=submit]').prop('disabled', true);
  $.ajax({
    method: 'POST',
    url: '/api/resource',
    data: $(this).serialize(),
    success: function(data) {
      showSuccess('Saved successfully');
    },
    error: function(xhr) {
      showError(xhr.responseJSON?.message || 'An error occurred');
    },
    complete: function() {
      $btn.prop('disabled', false);
    }
  });
});
```

## Success Criteria

- Forms submit asynchronously without unexpected reloads
- Errors are displayed clearly for user correction
- No duplicate requests from repeated clicks

## Common Failure Modes

- Ignoring CSRF tokens causing security vulnerabilities
- No error feedback leaving users confused
- Multiple submissions due to missing button disabling
