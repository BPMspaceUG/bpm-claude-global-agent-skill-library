---
name: c-bpm-sk-skill-creator
description: >
  Create new custom skills with Skills 2.0 features and automatic detection of
  existing c-bpm-sk- versions. Use when the user wants to create a new skill. If a
  c-bpm-sk- version already exists, delegates to c-bpm-sk-skill-optimizer instead. Enforces
  c-bpm- naming convention, segregation of duty, and Codex review. Derived from
  skill-creator with Skills 2.0 enhancements.
model: opus
disable-model-invocation: true
argument-hint: "[skill-name]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Skill Creator (Custom)

Create new skills with Skills 2.0 features, built-in existence checks, and
automatic delegation to the optimizer for existing skills.

## Decision Flow

**BEFORE creating any skill, run this check:**

```
1. User requests: "create/build/make a skill for X"
2. Determine skill name → c-bpm-sk-<name>
3. Check: does ~/.claude/skills/c-bpm-sk-<name>/ already exist?
   ├── YES → STOP. Delegate to c-bpm-sk-skill-optimizer (optimize/update existing)
   └── NO  → Continue with creation workflow below
4. Check: does an original skill exist to fork from?
   ├── YES → Fork workflow (copy original, rename to c-bpm-sk-, modify)
   └── NO  → From-scratch workflow
```

### Existence Check

```bash
ls -d ~/.claude/skills/c-bpm-sk-*<name>*/ 2>/dev/null && echo "EXISTS" || echo "NEW"
```

If the skill already exists:
- **Do NOT create a new one**
- **Inform the user**: "A custom version already exists. Switching to optimization mode."
- **Load `c-bpm-sk-skill-optimizer`** and follow its optimization workflow instead

## Skills 2.0 Frontmatter Decision Guide

When creating a skill, decide which frontmatter fields to include:

| Question | If YES → Add |
|----------|-------------|
| Should only the user trigger this? | `disable-model-invocation: true` |
| Should only Claude trigger this? | `user-invocable: false` |
| Does it accept arguments? | `argument-hint: "[description]"` |
| Should it run isolated? | `context: fork` + optional `agent: <type>` |
| Can tool access be restricted? | `allowed-tools: Tool1, Tool2` |
| Does it need a specific model? | `model: opus` or `model: sonnet` |
| Does it need runtime data? | Use `!`command`` dynamic injection |
| Does it reference bundled files? | Use `${CLAUDE_SKILL_DIR}` |

## Creation Workflow (New Skills Only)

### Step 1: Understand the Skill

Ask the user 2-3 concrete questions:
- What functionality should it support?
- Example prompts that should trigger it?
- Should it be user-invoked, Claude-invoked, or both?

### Step 2: Plan Structure

Analyze each use case to identify:
- **Scripts** (`scripts/`) — Code that needs deterministic reliability
- **References** (`references/`) — Documentation Claude should reference
- **Assets** (`assets/`) — Templates, icons, boilerplate files
- **Frontmatter fields** — Which Skills 2.0 features apply?

### Step 3: Initialize

```bash
mkdir -p ~/.claude/skills/c-bpm-sk-<name>
```

For forks, copy the original:

```bash
cp -r ~/.claude/skills/<original>/ ~/.claude/skills/c-bpm-sk-<original>/
# OR from marketplace:
cp -r ~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/<original>/ ~/.claude/skills/c-bpm-sk-<original>/
```

### Step 4: Implement

Write SKILL.md with Skills 2.0 frontmatter:

```yaml
---
name: c-bpm-sk-<name>
description: >
  [What it does]. [When to use it — triggers]. Derived from <original>.
disable-model-invocation: true     # If task skill
allowed-tools: Read, Grep, Glob    # If tool restrictions apply
argument-hint: "[arg]"             # If arguments expected
context: fork                      # If should run isolated
agent: Explore                     # If specific agent type needed
model: opus                        # If specific model needed
---
```

Create scripts, references, assets as identified in Step 2.

### Step 5: Codex Review

```bash
codex exec --skip-git-repo-check "Review this Claude Code skill for Skills 2.0 compliance. Check:
1. Frontmatter: name (c-bpm-sk- prefix), description (triggers), Skills 2.0 fields
2. Progressive disclosure: SKILL.md under 500 lines, references split out
3. No duplication between SKILL.md and reference files
4. Examples are concrete and minimal
5. Constraints are actionable (MUST/MUST NOT)
6. No unnecessary files (README.md, CHANGELOG.md, etc.)
7. Original skill untouched (if forked)
Skill content: <skill content>"
```

If Codex is unavailable, try the fallback chain: Codex → Gemini (`gemini` CLI) → any available model. If ALL unavailable: notify user, do not proceed without independent review. Log which reviewer was used.

### Step 6: Iterate

After real usage, improvements go through `c-bpm-sk-skill-optimizer`.

## Rules

### Naming
- ALL custom skills use `c-bpm-sk-` prefix — no exceptions
- Original skills keep their name — never rename them

### Segregation of Duty
- **NEVER modify files in `plugins/marketplaces/`** — read-only originals
- **NEVER modify non-prefixed skills** unless confirmed user-created
- Fork first, then modify the `c-bpm-sk-` version

### Progressive Disclosure
- SKILL.md body under 500 lines
- Split detailed content into `references/` files
- Reference files linked from SKILL.md with clear "Read when:" guidance

### No Clutter
- No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md
- Only SKILL.md + scripts/ + references/ + assets/ as needed

## Library Integration

After creating a skill, use `c-bpm-cm-library-push` to sync to Git.
