---
name: c-bpm-cm-skill-creator
description: >
  This command should be used when the user asks to "create a skill", "new skill", "make a skill",
  "add skill", "build skill". Detects existing c-bpm-sk- versions; delegates to optimizer if found.
  Enforces naming convention and Codex review.
argument-hint: "[skill-name]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
model: opus
---

# Skill Creator (Custom)

Create new skills with built-in awareness of existing custom versions. Extends the original `skill-creator` with existence checks, automatic delegation, and custom workflow rules.

## Decision Flow

**BEFORE creating any skill, run this check:**

```
1. User requests: "create/build/make a skill for X"
2. Determine skill name → c-bpm-sk-<name>
3. Check: does ~/.claude/skills/c-bpm-sk-<name>/ already exist?
   ├── YES → STOP. Delegate to c-bpm-cm-skill-optimizer (optimize/update existing)
   └── NO  → Continue with creation workflow below
4. Check: does an original skill exist to fork from?
   ├── YES → Fork workflow (copy original, rename to c-bpm-sk-, modify)
   └── NO  → From-scratch workflow
```

### Existence Check

```bash
ls -d ~/.claude/skills/c-bpm-sk-<name>/ 2>/dev/null && echo "EXISTS" || echo "NEW"
```

If the skill already exists:
- **Do NOT create a new one**
- **Inform the user**: "A custom version `c-bpm-sk-<name>` already exists. Switching to optimization mode."
- **Load `c-bpm-cm-skill-optimizer`** and follow its optimization workflow instead

## Creation Workflow (New Skills Only)

### Step 1: Understand the Skill

Ask the user concrete questions about how the skill will be used:
- What functionality should it support?
- Example prompts that should trigger it?
- What makes this different from existing skills?

Keep questions minimal — 2-3 per message, not a wall of questions.

### Step 2: Plan Reusable Contents

Analyze each use case to identify:
- **Scripts** (`scripts/`) — Code rewritten repeatedly, needs deterministic reliability
- **References** (`references/`) — Documentation Claude should reference while working
- **Assets** (`assets/`) — Files used in output (templates, icons, boilerplate)

### Step 3: Initialize

For new skills, use the `skill-creator` init script:

```bash
~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator/scripts/init_skill.py c-bpm-sk-<name> --path ~/.claude/skills/
```

For forks, copy the original:

```bash
cp -r ~/.claude/skills/<original>/ ~/.claude/skills/c-bpm-sk-<original>/
# OR from marketplace:
cp -r ~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/<original>/ ~/.claude/skills/c-bpm-sk-<original>/
```

### Step 4: Implement

1. Write/modify SKILL.md with proper frontmatter:
   ```yaml
   ---
   name: c-bpm-sk-<name>
   description: [What it does]. [When to use it]. Derived from <original> with <what's different>.
   ---
   ```
2. Create scripts, references, assets as identified in Step 2
3. Test scripts by running them
4. Delete unused example files from init
5. Remove `LICENSE.txt` if forked (custom skills don't carry original licenses)

### Step 5: Codex Review

```bash
codex exec --skip-git-repo-check -m gpt-5.2 "Review this Claude Code skill for quality. Check for:
1. Frontmatter: name (c-bpm-sk- prefix) and description (includes trigger conditions)
2. Progressive disclosure: SKILL.md under 500 lines, references split out
3. No duplication between SKILL.md and reference files
4. Examples are concrete and minimal
5. Constraints are actionable (MUST/MUST NOT)
6. No unnecessary files (README.md, CHANGELOG.md, etc.)
7. Original skill untouched (if forked)
Skill content: <skill content>"
```

### Step 6: Iterate

After real usage, the user may request improvements. At that point:
- **Load `c-bpm-cm-skill-optimizer`** — it handles all optimization workflows
- Do NOT re-run the creation workflow for existing skills

## Rules

### Naming
- ALL custom skills use `c-bpm-sk-` prefix — no exceptions
- Original skills keep their name — never rename them

### Segregation of Duty
- **NEVER modify files in `plugins/marketplaces/`** — these are read-only originals
- **NEVER modify non-prefixed skills in `skills/`** unless they are confirmed user-created
- Fork first, then modify the `c-bpm-sk-` version

### GitHub Issue Tracking
- Plans and progress go in GitHub Issues, not separate plan files
- Codex review results logged as issue comments

### Progressive Disclosure
- SKILL.md body under 500 lines
- Split detailed content into `references/` files
- Reference files linked from SKILL.md with clear "Read when:" guidance

### No Clutter
- No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, QUICK_REFERENCE.md
- Only SKILL.md + scripts/ + references/ + assets/ as needed

## Library Integration

After creating a skill, use `c-bpm-cm-library-push` to sync it to the Git repository. See `c-bpm-sk-library-manager` skill for the full push/pull workflow and conventions for all artefact types (not just skills).
