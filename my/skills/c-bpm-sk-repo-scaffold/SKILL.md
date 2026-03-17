---
model: opus
name: c-bpm-sk-repo-scaffold
description: Consistent starting point for new projects with directory layout, naming conventions, and baseline files. Use when starting a new project, restructuring a repository, or adding asset types (agents, skills, runbooks, templates). Includes Excalidraw diagram generation for visual documentation. Derived from S01.
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

## Success Criteria

- A newcomer can understand the repository structure at a glance
- Baseline files (.gitignore, README, LICENSE) are present and informative
- Templates exist to streamline contributions
- Key architecture or workflows are visualized as Excalidraw diagrams

## Common Failure Modes

- Missing or inconsistent directories
- Lack of README or minimal description
- Ignoring files that should be committed
