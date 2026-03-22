---
name: c-bpm-sk-skill-optimizer
description: >
  This skill should be used when the user asks to "optimize a skill", "improve skill",
  "refactor skill", "upgrade skill", "enhance skill", "add Skills 2.0 features to a skill",
  or wants to audit an existing skill against the Skills 2.0 checklist. Adds frontmatter,
  supporting files, dynamic context, subagent config. Enforces c-bpm- naming.
model: opus
disable-model-invocation: true
user-invocable: true
argument-hint: "[skill-name]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

## Currently Installed Custom Skills

The following c-bpm-sk- skills are installed locally. If the list is empty, no custom skills are currently installed.

!`ls -d ~/.claude/skills/c-bpm-sk-* 2>/dev/null | xargs -I{} basename {} | sort`

# Skill Optimizer

Optimize, upgrade, and refactor skills for personal use. Extends `skill-creator`
with Skills 2.0 features, strict separation of originals vs. custom skills,
Codex review gates, and team orchestration support.

## Skills 2.0 Feature Checklist

When optimizing a skill, check whether these features would improve it:

| Feature | When to Add |
|---------|-------------|
| `disable-model-invocation: true` | Task skills with side effects (deploy, build, commit) |
| `user-invocable: false` | Background knowledge Claude should auto-load but users should not invoke |
| `allowed-tools` | Restrict tool access for safety (e.g., read-only skills) |
| `context: fork` | Skills that should run in an isolated subagent |
| `agent` | Specify subagent type (`Explore`, `Plan`, custom) when using `context: fork` |
| `argument-hint` | Skills that accept arguments — show hint in autocomplete |
| `hooks` | Skills needing lifecycle event handling |
| `model` | Override model for specific skills (e.g., `opus` for complex tasks) |
| `effort` | Override model effort level (e.g., `high` for thorough analysis) |
| `!`command`` | Dynamic context injection — run shell commands before prompt |
| `${CLAUDE_SKILL_DIR}` | Reference scripts/files bundled with the skill |
| `${CLAUDE_SESSION_ID}` | Session-specific logging or file creation |
| `$ARGUMENTS[N]` / `$N` | Positional argument access |
| Supporting files | Templates, scripts, examples in subdirectories |

## Segregation of Duty

The most important principle: **original skills are read-only**.

| Action | Allowed? | How |
|--------|----------|-----|
| Read original skill | YES | Read from `plugins/marketplaces/` or `skills/<original-name>/` |
| Modify original skill | **NEVER** | Fork to `c-bpm-sk-` version first |
| Delete original skill | **NEVER** | Uninstall via marketplace only |
| Create custom skill | YES | Always with `c-bpm-sk-` prefix |
| Fork original to custom | YES | Copy, rename with `c-bpm-sk-` prefix, then modify |

## The `c-bpm-` Naming Convention

**Custom/optimized skills MUST use the `c-bpm-sk-` prefix.**

| Scenario | Name | Example |
|----------|------|---------|
| Installed/original skill | Keep original name | `frontend-design`, `skill-creator` |
| New custom skill | `c-bpm-sk-` + descriptive name | `c-bpm-sk-flightphp-pro` |
| Forked/optimized original | `c-bpm-sk-` + original name | `c-bpm-sk-skill-creator` |

### Identifying Custom vs. Original

- `LICENSE.txt` present → likely an installed original
- No `LICENSE.txt` → likely user-created
- Directory starts with `c-bpm-sk-` → definitively user-created/optimized
- Located in `plugins/marketplaces/` → always original, never touch

## Optimization Workflow

### Step 1: Audit Current Skill

Read the skill and evaluate against Skills 2.0 checklist:

```bash
cat "${CLAUDE_SKILL_DIR}/../<skill-name>/SKILL.md"
```

Check:
1. **Frontmatter completeness** — missing fields from the checklist above?
2. **Invocation control** — should Claude auto-invoke? Should users invoke?
3. **Tool restrictions** — can we limit `allowed-tools` for safety?
4. **Isolation** — should this run in a subagent (`context: fork`)?
5. **Arguments** — does it use `$ARGUMENTS`? Could it use positional `$N`?
6. **Dynamic context** — could `!`command`` inject useful data?
7. **Supporting files** — should large reference content be split out?
8. **SKILL.md size** — over 500 lines? Split into references/

### Step 2: Plan Changes

Document what will change and why. Present to user for approval.

### Step 3: Apply Changes

1. Fork first if modifying a non-`c-bpm-sk-` skill
2. Update frontmatter with new fields
3. Refactor content for Skills 2.0 patterns
4. Move large sections to supporting files if needed
5. Add scripts to `scripts/` if `${CLAUDE_SKILL_DIR}` references needed

### Step 4: Codex Review

```bash
codex exec --skip-git-repo-check "Review this Claude Code skill for Skills 2.0 compliance. Check:
1. Frontmatter: all relevant Skills 2.0 fields present (disable-model-invocation, allowed-tools, context, agent, argument-hint)
2. SKILL.md under 500 lines, references split out
3. No duplication between SKILL.md and reference files
4. Dynamic context injection used where beneficial
5. Supporting files properly referenced
6. Naming convention (c-bpm-sk- prefix for custom skills)
Skill content: <skill content>"
```

If Codex is unavailable, try the fallback chain: Codex → Gemini (`gemini` CLI) → any available model. If ALL unavailable: notify user, do not proceed without independent review. Log which reviewer was used.

Follow `c-bpm-sk-milestone-type` for issue lifecycle and type enforcement when creating or tracking issues.

### Step 5: Test

Verify the optimized skill:
- Triggers correctly (or is correctly hidden from auto-invocation)
- Arguments work as expected
- Tool restrictions don't break functionality
- Subagent mode works if `context: fork` is set

## Frontmatter Template (Skills 2.0)

```yaml
---
name: c-bpm-sk-example
description: >
  This skill should be used when the user asks to "[trigger phrase 1]", "[trigger phrase 2]".
  [What it does]. Derived from [original].
model: opus                        # Optional: override model
effort: high                       # Optional: override effort level
disable-model-invocation: true     # Optional: manual-only
user-invocable: true               # Optional: hide from / menu
allowed-tools: Read, Grep, Glob    # Optional: tool whitelist
context: fork                      # Optional: run in subagent
agent: Explore                     # Optional: subagent type
argument-hint: "[arg1] [arg2]"     # Optional: autocomplete hint
---
```

## Directory Layout

```
~/.claude/skills/
├── skill-creator/            # Original (installed) — READ ONLY
├── c-bpm-sk-skill-creator/     # Custom (derived from skill-creator)
├── c-bpm-sk-skill-optimizer/   # Custom (this skill)
│   ├── SKILL.md              # Main instructions (required)
│   └── references/           # Optional supporting files
│       └── team-orchestration.md
└── ...
```

## Library Integration

After optimizing a skill, use `c-bpm-cm-library-push` to sync to Git.

## Reference Files

### `references/team-orchestration.md`
Read when: orchestrating a team to build or refactor multiple skills in parallel,
setting up milestone-based issue tracking, spawning agent teammates, running
Codex review gates, or managing the full lifecycle from discovery through PR.
