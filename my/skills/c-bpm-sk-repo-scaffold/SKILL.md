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
