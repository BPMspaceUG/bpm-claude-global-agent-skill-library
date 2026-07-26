---
name: c-bpm-sk-release-ops
description: "Release operations — cut a release, versioning, CI/CD setup, deployment, rollback, artefact packaging. Controlled release process and deployment playbooks."
enforcement: block
intentPatterns: "cut a release;;release (operations|ops);;(setup|configure) ci/cd;;deployment (playbook|rollback);;artefact packaging"
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Release & Ops (CI/CD, Versioning & Rollback)

Controlled process for releasing software including versioning, CI/CD, artefact packaging and rollback procedures.

## Checklist

- [ ] Semantic versioning (`MAJOR.MINOR.PATCH`)
- [ ] `CHANGELOG.md` documenting changes per release
- [ ] Tag releases in VCS with attached artefacts (zips, tarballs)
- [ ] CI pipeline (GitHub Actions): tests on every push, artefacts on tags
- [ ] Publish artefacts to registry or release page
- [ ] Include install/update script in release
- [ ] Rollback procedures: revert version, restore data, notify stakeholders
- [ ] Health checks and alerting for deployments
- [ ] Document release process, automate where possible

## Snippets

```yaml
# GitHub Actions (simplified)
on:
  push:
    tags:
      - 'v*.*.*'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: ./scripts/test.sh
      - name: Build artefact
        run: zip -r release.zip .
      - name: Upload release artefact
        uses: actions/upload-artifact@v3
        with:
          name: release
          path: release.zip
```

## Judge Review Gate

Before executing any destructive or irreversible operation (release cut, tag
creation, artefact publishing), run the review via `c-bpm-sk-devils-advocate`
(Codex primary; OpenRouter fallback per `c-bpm-sk-llm-selection`), asking the Judge:

> Review this release plan: `<plan>`. Check: correct versioning, no breaking
> changes, follows project conventions. Approve or reject.

If every tier of the substitute-Judge ladder is unreachable: STOP and notify the user.

## Success Criteria

- Releases are repeatable and documented
- CI/CD runs automatically and reports status
- Artefacts available for download and installation
- Rollback steps exist and have been tested

## Common Failure Modes

- Inconsistent version numbers across code and metadata
- Missing changelog or release notes
- Manual deployments leading to human error
- No rollback plan causing extended downtime

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
