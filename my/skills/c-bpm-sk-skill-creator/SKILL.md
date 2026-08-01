---
name: c-bpm-sk-skill-creator
description: "Create a new skill — create skill, new skill, make skill, add skill, build skill, fork skill, scaffold skill. Skills 2.0 features; auto-detects existing c-bpm-sk- versions and delegates to optimizer. Enforces naming and Codex review."
enforcement: block
intentPatterns: "create (a |new )?skill;;new skill;;make (a )?skill;;build (a )?skill;;add (a )?skill"
user-invocable: true
argument-hint: "[skill-name]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

## Currently Installed Custom Skills

The following c-bpm-sk- skills are installed locally. If the list is empty, no custom skills are currently installed.

!`ls -d ~/.claude/skills/c-bpm-sk-* 2>/dev/null | xargs -I{} basename {} | sort`

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
| Should only Claude trigger this? | `user-invocable: false` |
| Does it accept arguments? | `argument-hint: "[description]"` |
| Should it run isolated? | `context: fork` + optional `agent: <type>` |
| Can tool access be restricted? | `allowed-tools: Tool1, Tool2` |
| Should it override effort level? | `effort: high` or `effort: low` |
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
enforcement: block
intentPatterns: "create (a |new )?skill;;new skill;;make (a )?skill;;build (a )?skill;;add (a )?skill"
allowed-tools: Read, Grep, Glob    # If tool restrictions apply
argument-hint: "[arg]"             # If arguments expected
context: fork                      # If should run isolated
agent: Explore                     # If specific agent type needed
---
```

**No `model:` key, ever** (#121). Model choice is single-source policy and lives as
prose in `c-bpm-sk-llm-selection`; a frontmatter `model:` key bypasses it.

Create scripts, references, assets as identified in Step 2.

### Step 5: Judge Review

Run the review via `c-bpm-sk-devils-advocate` (Codex primary; OpenRouter fallback
per `c-bpm-sk-llm-selection`), asking the Judge to review the skill for Skills 2.0
compliance:

> 1. Frontmatter: name (c-bpm-sk- prefix), description (triggers), Skills 2.0 fields
> 2. Progressive disclosure: SKILL.md under 500 lines, references split out
> 3. No duplication between SKILL.md and reference files
> 4. Examples are concrete and minimal
> 5. Constraints are actionable (MUST/MUST NOT)
> 6. No unnecessary files (README.md, CHANGELOG.md, etc.)
> 7. Original skill untouched (if forked)
> Skill content: `<skill content>`

`c-bpm-sk-devils-advocate` descends the substitute-Judge ladder when Codex is
unreachable. If every tier is unreachable: notify user, do not proceed without
independent review. Log which Judge produced the verdict.

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

### Issue Lifecycle
- Follow `c-bpm-sk-milestone-type` for issue lifecycle and type enforcement when creating or tracking issues

### Progressive Disclosure
- SKILL.md body under 500 lines
- Split detailed content into `references/` files
- Reference files linked from SKILL.md with clear "Read when:" guidance

### Must-Stay Rule (F3)

New skills are **born compliant**: this content goes in SKILL.md and is never placed in
`references/`, no matter how long the body gets.

- Frontmatter
- Skill purpose statement (≤ 3 lines)
- Trigger conditions / when-to-use
- Safety constraints / refusal rules
- Required tool-call order / phase gates
- Non-obvious defaults
- Critical fallback chain
- MVP scope exclusions
- Cross-skill protocol references (link only)

**May move to `references/`:** detailed examples, long bash blocks, reference tables,
multi-agent boilerplate, per-tech checklists, historical notes, tutorials.

Verify with the three-check protocol before finishing: the body alone must still answer
"when do I invoke this?" and "what must I never do here?", and deleting `references/`
must still leave a safe (if lower-quality) skill. Full protocol and the structural
scorecard: `c-bpm-sk-library-manager` → `references/skill-audit-policy.md`.

### No Clutter
- No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md
- Only SKILL.md + scripts/ + references/ + assets/ as needed

## Upstream Capabilities

The original `skill-creator` (installed via marketplace) includes additional features
not replicated here: eval/benchmark workflows, description optimization via `run_loop.py`,
and blind A/B comparison. For these advanced workflows, load the original `skill-creator`
skill directly.

## Library Integration

After creating a skill, use `c-bpm-cm-library-push` to sync to Git.

## Why this skill is not merged with `c-bpm-sk-skill-optimizer`

The creator/optimizer pair is a **principled split** by lifecycle stage — create →
optimize — with zero `intentPattern` overlap. This skill's existence check *hands off*
to the optimizer; merging them would delete the check that stops duplicate skills from
being created. Do not propose a merge without first refuting that split axis in the
Issue. Registry of principled splits: `c-bpm-sk-library-manager` →
"Principled Splits (do not merge)".

## Findings → Issues

Every finding this skill surfaces — bug, optimization, gap, decision-needed,
even a maybe-not-OK hunch — is filed as a GitHub Issue **immediately**, one
issue per discrete finding, at the moment it is found. Never ask first;
over-filing is fine, asking is not. Dedup before filing: search open issues
and skip only on a genuine match (note "already tracked: #N"). Every created
issue gets milestone `new` and exactly one type label — `bug` or
`enhancement` (lowercase) — at creation; issue-write-gate enforces both
mechanically. The user decides afterwards which issues are kept or worked on.

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
