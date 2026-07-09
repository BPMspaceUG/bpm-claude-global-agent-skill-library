---
model: opus
name: c-bpm-sk-repo-scaffold
description: "Scaffold a repo — new project, project structure, directory layout, init repo, repository template, Excalidraw diagrams. Consistent starting point with baseline files."
enforcement: block
intentPatterns: "scaffold (a )?(new )?(repo|project);;(new |init )project (structure|scaffold);;directory layout (template|scaffold);;repository template"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
argument-hint: "[project-name or path]"
---

# Repo & Project Scaffold

Provide a consistent starting point for new projects, ensuring that directory layout, naming conventions and baseline files are predictable across teams.

## When to Use

- At the beginning of a new project
- When restructuring an existing repository
- When adding a new asset type (agents, skills, runbooks, templates)

## Checklist

- [ ] Create top-level directories: `agents/`, `skills/`, `runbooks/`, `templates/`
- [ ] Add `.gitignore` appropriate for the technologies used
- [ ] Include `README.md` with purpose, install, and usage instructions
- [ ] Create architecture or workflow diagrams using `excalidraw-diagram-generator` skill (`.excalidraw` files in `docs/`)
- [ ] Include `LICENSE` file when applicable
- [ ] Add sample files or placeholders for each directory
- [ ] Add issue and PR templates under `templates/`

## Minimal Snippets

```
.
├── agents/
├── skills/
├── runbooks/
├── templates/
├── docs/
│   └── architecture.excalidraw
├── .gitignore
└── README.md
```

## Codex Review Gate

Before executing any destructive or irreversible operation (directory scaffolding, file overwriting, project restructuring), submit plan to Codex for review:

```bash
codex exec --skip-git-repo-check "Review this scaffold plan: <plan>. Check: correct structure, no breaking changes, follows project conventions. Approve or reject."
```

If Codex is unavailable, try the fallback chain: Codex → Gemini (`gemini` CLI) → any available model. If ALL unavailable: STOP and notify the user.

## Success Criteria

- A newcomer can understand the repository structure at a glance
- Baseline files (.gitignore, README, LICENSE) are present and informative
- Templates exist to streamline contributions
- Key architecture or workflows are visualized as Excalidraw diagrams

## Common Failure Modes

- Missing or inconsistent directories
- Lack of README or minimal description
- Ignoring files that should be committed

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
