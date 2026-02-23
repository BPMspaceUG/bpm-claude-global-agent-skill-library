# Question Audit Report Template

Use this template when generating the audit report.

```markdown
# Question Audit Report: {topic_name}

## Report Metadata

| Field | Value |
|-------|-------|
| Report ID | `{YYMMDD-HHMMSS}-{topic_uuid_short}` |
| Topic UUID | `{topic_uuid}` |
| Topic Name | {topic_name} |
| Filter | {published / unpublished / all} |
| Certificate Level | {Foundation / Professional / unknown} |
| Audit Date | {YYYY-MM-DD HH:MM:SS} |
| Auditor | Claude Opus 4.6 -- `my-bpm-question-auditor` |
| Questions Audited | {total_count} |
| Previous Report | {filename or "none"} |

## Summary

**Verdict: {PASS / FAIL}**

| Category | Count |
|----------|-------|
| Critical | {n} |
| Major | {n} |
| Irrelevant | {n} |
| Suggestions | {n} |

{1-3 sentences overall assessment}

{If previous report exists:}
### Changes Since Last Audit

- **New findings:** {n}
- **Resolved:** {n}
- **Persistent:** {n}

---

## 1. Critical Findings

Wrong answer markings that MUST be fixed before publishing.

| # | Question UUID | Answer UUID | Question (short) | Answer (short) | Marked | Should Be | Evidence |
|---|---------------|-------------|------------------|----------------|--------|-----------|----------|
| C-1 | `{q_uuid}` | `{a_uuid}` | {first 60 chars} | {first 60 chars} | {true/false} | {true/false} | {why} |

{If translation-critical:}

| # | Question UUID | Answer UUID | DE Text (short) | EN Text (short) | Issue |
|---|---------------|-------------|-----------------|-----------------|-------|
| C-T1 | `{q_uuid}` | `{a_uuid}` | {DE} | {EN} | {meaning differs} |

---

## 2. Major Findings

Distractor quality, hints in question text, ambiguous answers.

| # | Question UUID | Answer UUID | Question (short) | Issue | Recommendation |
|---|---------------|-------------|------------------|-------|----------------|
| M-1 | `{q_uuid}` | `{a_uuid}` | {first 60 chars} | {what's wrong} | {how to fix} |

---

## 3. Irrelevant Questions

Questions that do not belong to this topic or test unnecessary knowledge.

| # | Question UUID | Question (short) | Reason |
|---|---------------|------------------|--------|
| I-1 | `{q_uuid}` | {first 60 chars} | {why irrelevant} |

---

## 4. Suggestions

Optional improvements. Can be suppressed with `--no-suggestions`.

| # | Question UUID | Answer UUID | Question (short) | Suggestion |
|---|---------------|-------------|------------------|------------|
| S-1 | `{q_uuid}` | `{a_uuid}` | {first 60 chars} | {improvement} |

---

## 5. Diff vs Previous Audit

{Only if a previous report was found}

### New Findings (not in previous report)
{list of finding IDs}

### Resolved (in previous report, not in this one)
{list of finding IDs from previous report}

### Persistent (in both reports)
{list of finding IDs}
```

## Naming Convention

**Filename:** `question-audit_{topic-slug}_{YYMMDD-HHMMSS}.md`

- `topic-slug`: lowercase, hyphens, max 40 chars (e.g., `artificial-intelligence`)
- Timestamp: report generation time

**Location:** `reports/{topic_uuid}/`

## Verdict Rules

- **FAIL** if any CRITICAL findings exist
- **PASS** if no CRITICAL findings (MAJOR/SUGGESTIONS don't cause FAIL)
