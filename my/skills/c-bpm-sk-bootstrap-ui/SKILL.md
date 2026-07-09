---
model: opus
name: c-bpm-sk-bootstrap-ui
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

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
