---
name: c-bpm-sk-jquery-ajax-forms
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

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
