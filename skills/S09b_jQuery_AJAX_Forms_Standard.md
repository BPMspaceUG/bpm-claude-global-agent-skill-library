# Skill S09b – jQuery AJAX & Forms Standard

## Goal

Define patterns for handling forms and AJAX requests with jQuery in a safe and maintainable way. This includes proper error handling, CSRF protection and user feedback.

## When to Use

- When submitting forms without a full page reload.
- When performing asynchronous requests to update parts of the UI.

## Checklist

- [ ] Include the CSRF token in AJAX headers or payloads when required.
- [ ] Use `$.ajax` or `.fetch()` with success and error callbacks; handle HTTP errors explicitly.
- [ ] Display loading indicators while requests are pending.
- [ ] Provide feedback to the user on success (e.g. flash messages, modal updates).
- [ ] Validate form inputs both client‑side and server‑side.
- [ ] Prevent double submissions by disabling the submit button until the request completes.
- [ ] Escape any user-provided content before inserting into the DOM.
- [ ] Use event delegation when binding handlers to dynamically created elements.

## Minimal Snippets

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

- Forms are submitted asynchronously without unexpected reloads.
- Errors are displayed clearly and allow the user to correct them.
- Users cannot submit duplicate requests inadvertently.

## Common Failure Modes

- Ignoring CSRF tokens, leading to security vulnerabilities.
- No feedback on errors, leaving users confused.
- Multiple submissions due to missing button disabling.