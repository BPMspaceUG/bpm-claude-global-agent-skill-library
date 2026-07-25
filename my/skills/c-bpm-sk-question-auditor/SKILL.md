---
name: c-bpm-sk-question-auditor
description: >
  Audits exam question quality for a Topic via EduMS3 php-crud-api. Checks answer
  correctness (wrong marked as right, right marked as wrong), distractor quality,
  translation DE/EN, and relevance. Produces a diff-capable Markdown report with
  question UUIDs. Supports --published, --unpublished, --all filters. Trigger for:
  question audit, exam quality check, Q&A review, Pruefungsfragen pruefen,
  Fragenqualitaet, question quality.
user-invocable: true
---

# /c-bpm-sk-question-auditor — Exam Question Quality Auditor

Audits all exam questions assigned to a **Topic** in EduMS3. Focuses purely on
question quality — not syllabus structure. Produces a Markdown report.

**REPORT ONLY — never modifies questions.**

## When to Use

- "Audit the questions for topic X"
- "Check question quality"
- "Review exam questions"
- "Are there wrong answers?"
- "Pruefungsfragen pruefen"

## Inputs

The user provides:
- **Topic UUID** (required)
- **Filter** (optional): `--published`, `--unpublished`, or `--all` (default: `--all`)

## Environment

Requires `.env` in the project root (or `~/.config/cac/.env`) with:

```bash
EduMS3_Hostname_RO_API=https://api.example.com/
EduMS3_HostnameToken_RO_API=base64encodedcredentials
```

If not found, STOP and ask the user.

## API Access

EduMS3 uses [php-crud-api](https://github.com/mevdschee/php-crud-api). See `references/edums3-api.md`.

## Severity Levels

| Level | Meaning | Example |
|-------|---------|---------|
| **CRITICAL** | Factually wrong marking | Correct answer marked false, or false answer marked correct |
| **MAJOR** | Distractor too easy or answer ambiguous | Obviously wrong distractor, question hints at answer |
| **SUGGESTION** | Improvement opportunity | Better wording, clearer phrasing |
| **IRRELEVANT** | Question does not belong | Question tests knowledge unrelated to the topic |

## Audit Workflow

### Step 1: Load Environment

```bash
source .env 2>/dev/null || source ~/.config/cac/.env 2>/dev/null
```

Verify `EduMS3_Hostname_RO_API` and `EduMS3_HostnameToken_RO_API` are set.

### Step 2: Fetch Questions

See `references/edums3-api.md` for exact curl commands per filter mode.

### Step 3: Check for Previous Report

Look for existing reports in `reports/<topic_uuid>/`:

```bash
ls reports/<topic_uuid>/question-audit_*.md 2>/dev/null | sort | tail -1
```

If a previous report exists, load it for comparison in Step 7.

### Step 4: Optionally Fetch Context

If the user wants level-appropriate checks (Foundation vs Professional), fetch
syllabus context to determine the certification level. See `references/edums3-api.md`
for the syllabus lookup path.

This step is optional — the audit works without it.

### Step 5: Audit Each Question

For every question, check:

#### 5.1 Answer Correctness (→ CRITICAL)

- Every answer marked `is_correct: true` MUST be genuinely correct
- Every answer marked `is_correct: false` MUST be genuinely wrong
- No ambiguity — if debatable, escalate to Codex

#### 5.2 Distractor Quality (→ MAJOR)

- Wrong answers must be plausible, not obviously absurd
- Wrong answers must be definitively wrong, not partially correct
- No pattern that reveals the answer (e.g., correct answer always longest)
- Question text must not hint at the correct answer
- For Foundation (3 answers): basic difficulty
- For Professional (4 answers): higher difficulty, scoring requires all correct + none wrong

#### 5.3 Translation Quality (→ CRITICAL if meaning differs, SUGGESTION if style)

- DE and EN versions must express the same meaning
- Domain terms correctly used (see domain term list in `references/edums3-api.md`)
- If meaning diverges between DE and EN: CRITICAL
- If just style/wording could be better: SUGGESTION

#### 5.4 Relevance (→ IRRELEVANT)

- Question must test knowledge related to the topic
- Question must test knowledge someone needs to know for the certification
- Obscure trivia or unrelated knowledge = IRRELEVANT

### Step 6: Judge Escalation

For ambiguous cases (especially answer correctness), run the review via
`c-bpm-sk-devils-advocate` (Codex primary; OpenRouter fallback per
`c-bpm-sk-llm-selection`), asking the Judge:

> Evaluate this exam question. Is the answer marking correct? Question: `${Q_TEXT}`
> Answer: `${A_TEXT}` Marked as: `${IS_CORRECT}`. Topic context: `${TOPIC_NAME}`.
> Respond: CORRECT, INCORRECT, or AMBIGUOUS with evidence.

### Step 7: Generate Report

Use the template from `references/report-template.md`.

**Filename:** `question-audit_<topic-slug>_<YYMMDD-HHMMSS>.md`
**Location:** `reports/<topic_uuid>/`

Create the directory if it does not exist.

### Step 8: Diff Against Previous

If a previous report exists (from Step 3):
- Note which findings are **NEW** (not in previous report)
- Note which findings are **RESOLVED** (in previous report but not in this one)
- Note which findings **PERSIST** (in both)

Add a diff summary section at the end of the report.

## Report Structure

See `references/report-template.md` for the full template. Summary:

```
1. Summary (counts, verdict, diff if applicable)
2. Critical Findings (wrong answer markings)
3. Major Findings (distractor/hint issues)
4. Irrelevant Questions
5. Suggestions (optional, can be suppressed with --no-suggestions)
6. Diff vs Previous Audit (if applicable)
```

Every finding row MUST include the **question UUID** and **answer UUID** for direct DB lookup.

## Constraints

### MUST
- Include question UUID and answer UUID in every finding
- Store reports in `reports/<topic_uuid>/` for diff capability
- Check for previous reports before generating new one
- Use Codex for ambiguous answer correctness cases
- Respect filter mode (published/unpublished/all)
- Exclude soft-deleted questions (filter `deleted_at,nl`)

### MUST NOT
- Modify any questions or answers
- Create GitHub issues (report only)
- Skip answer correctness checks
- Use sequential identifiers (Q1, Q2) — always use UUIDs
- Include soft-deleted questions

### ON BLOCKERS
- API unreachable → STOP, inform user
- Missing credentials → STOP, ask user for .env
- Codex unavailable → note in report, proceed with own assessment
- No questions returned → report "0 questions found", check filter

## References

- `references/edums3-api.md` — API endpoints, curl commands, response structure
- `references/report-template.md` — Full report Markdown template

<!-- BEGIN issue-comms (stamped block — do not edit in stamped files; edit my/shared/issue-communication-protocol.md and run scripts/stamp-issue-protocol.sh) -->
## Communication: GitHub Issues only

All work for this item is documented in its GitHub Issue — never in side-car files.

- **The Issue is the single source of truth.** The task, the plan, why a plan was rejected, the revised plan, progress, and every decision go in the Issue body or comments — posted as they happen.
- **No side-car MD files, ever.** Never write `~/.claude/plans/*.md`, scratchpad `prompt.md` / plan `.md`, `ISSUE_<n>_PLAN.md`, or any doc that duplicates what belongs in the Issue. Plan/review artifacts the harness writes (e.g. ExitPlanMode into `~/.claude/plans/*.md`) are **transient and non-authoritative** — mirror them into the Issue immediately and treat the Issue as the record.
- **Codex is invoked by Issue reference, not by pasting a plan into a file.** Fetch the Issue **body and its comments** live and pipe them to a sanitized `codex exec` — e.g. `gh api repos/<owner>/<repo>/issues/<n> --jq .body` **and** `gh api repos/<owner>/<repo>/issues/<n>/comments`, piped in together. (`gh issue view --comments` is unreliable — it hits deprecated GraphQL and can return empty.) The stdin is Issue-sourced, never an authored `.md`.
- **Precedence:** this rule OVERRIDES any local "write a plan doc" / "save to a file" wording anywhere in this item. The only allowed non-Issue output is the terminal summary shown to the user; the durable record still lives in the Issue.

Canonical source: `my/shared/issue-communication-protocol.md`. Governance: `c-bpm-sk-milestone-type` (documentation rule) + `c-bpm-sk-llm-selection` (Codex-by-Issue).
<!-- END issue-comms -->
