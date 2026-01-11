# Skill S01 – Repo & Project Scaffold Standard

## Goal

Provide a consistent starting point for new projects, ensuring that directory layout, naming conventions and baseline files are predictable across teams. This standard helps reduce setup time and improves discoverability.

## When to Use

- At the beginning of a new project.
- When restructuring an existing repository to align with best practices.
- When adding a new type of asset (agents, skills, runbooks, templates) to a repository.

## Checklist

- [ ] Create top‑level directories: `agents/`, `skills/`, `runbooks/`, `templates/`.
- [ ] Add a `.gitignore` file appropriate for the technologies used.
- [ ] Include a `README.md` that describes the purpose of the repository and how to install/use it.
- [ ] Include a `LICENSE` file when applicable.
- [ ] Add sample files or placeholders to demonstrate how each directory should be used.
- [ ] Add issue and pull‑request templates under `templates/`.

## Minimal Snippets

```
# Example directory tree
.
├── agents/
├── skills/
├── runbooks/
├── templates/
├── .gitignore
└── README.md
```

## Success Criteria

- A newcomer can understand the repository structure at a glance.
- Baseline files (.gitignore, README, LICENSE) are present and informative.
- Templates exist to streamline contributions and documentation.

## Common Failure Modes

- Missing or inconsistent directories leading to confusion.
- Lack of README or minimal description.
- Ignoring files that should be committed (e.g. agents or skills).