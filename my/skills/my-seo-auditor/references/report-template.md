# SEO Audit Report Templates

Exact templates for all reports. Every report MUST follow these structures verbatim so that reports from different runs can be compared side-by-side.

## INDEX.md Template

```markdown
# SEO Audit Run — {WEBSITE_URL}

| Field | Value |
|-------|-------|
| **Website** | {WEBSITE_URL} |
| **Timestamp (UTC)** | {YYYY-MM-DD_HH-MM-SS} |
| **Skill Versions** | seo-audit: {ver}, programmatic-seo: {ver}, seo-geo: {ver} |
| **Codex Version** | {codex --version output} |
| **Run By** | Claude Opus 4.6 |

## Reports

| # | Report | Codex Status | File |
|---|--------|--------------|------|
| 1 | Technical SEO Audit | APPROVED | [skill-1-seo-audit.md](skill-1-seo-audit.md) |
| 2 | Programmatic SEO Analysis | APPROVED | [skill-2-programmatic-seo.md](skill-2-programmatic-seo.md) |
| 3 | SEO/GEO Optimization | APPROVED | [skill-3-seo-geo.md](skill-3-seo-geo.md) |
| **Final** | **Unified Report** | **APPROVED** | [final-report.md](final-report.md) |

## Previous Runs

| Date | Directory |
|------|-----------|
| {previous YYYY-MM-DD_HH-MM-SS} | [link](../{previous-timestamp}/) |
```

---

## Individual Skill Report Template

Used by Agents 1, 2, and 3. The `{SKILL_SPECIFIC_SECTIONS}` vary per skill but the wrapper is identical.

```markdown
# {REPORT_TITLE}

## Metadata

| Field | Value |
|-------|-------|
| **Website** | {WEBSITE_URL} |
| **Report Type** | {skill-1-seo-audit | skill-2-programmatic-seo | skill-3-seo-geo} |
| **Skill Used** | {skill name} v{version} |
| **Timestamp (UTC)** | {YYYY-MM-DD_HH-MM-SS} |
| **Agent** | {agent-name} |
| **Codex Approval** | {PENDING | APPROVED | REVISION {N}} |

---

## Executive Summary

{3-5 sentence overview of findings. MUST include:}
- Overall health score: {CRITICAL | POOR | FAIR | GOOD | EXCELLENT}
- Number of findings by severity: {N critical, N high, N medium, N low}
- Top 3 priority actions

---

## Findings

### Finding {N}: {Title}

| Field | Value |
|-------|-------|
| **Severity** | {CRITICAL | HIGH | MEDIUM | LOW} |
| **Category** | {category from skill checklist} |
| **Evidence** | {URL, status code, screenshot, or specific observation} |
| **Impact** | {What happens if not fixed} |
| **Recommendation** | {Specific action to take} |
| **Owner** | {Dev | Content | SEO | Marketing} |
| **Effort** | {Low | Medium | High} |
| **Validation** | {How to verify the fix works} |

{Repeat for each finding. Number sequentially. Do NOT skip any checklist items — if checked and OK, list as:}

### Finding {N}: {Title} — OK

| Field | Value |
|-------|-------|
| **Severity** | OK |
| **Evidence** | {What was checked and found correct} |

---

## Checklist Coverage

| Checklist Item | Status | Finding # |
|----------------|--------|-----------|
| {item from skill} | {OK | ISSUE | N/A} | {#N or —} |
{Every item from the skill's audit checklist MUST appear here}

---

## Prioritized Action Plan

| Priority | Finding # | Action | Owner | Effort | Timeline |
|----------|-----------|--------|-------|--------|----------|
| 1 | #{N} | {action} | {owner} | {effort} | {week/month} |
| 2 | #{N} | {action} | {owner} | {effort} | {week/month} |
{Ordered by: CRITICAL first, then HIGH, then by effort (low first)}

---

## Validation Test Plan

| Test # | Finding # | Test Description | Expected Result | How to Run |
|--------|-----------|------------------|-----------------|------------|
| T{N} | #{N} | {what to test} | {expected outcome} | {command or tool} |
{Every recommendation MUST have at least one validation test}

---

## Raw Data

{Any raw data, curl outputs, tool results collected during the audit. Preserve for reproducibility.}
```

---

## Skill-Specific Sections

### Agent 1 (seo-audit) — Categories to Cover

All categories from the seo-audit SKILL.md checklist:
1. Crawlability (robots.txt, sitemap, architecture, crawl budget)
2. Indexation (index status, issues, canonicalization)
3. Site Speed & Core Web Vitals (LCP, INP, CLS)
4. Mobile-Friendliness
5. Security & HTTPS
6. URL Structure
7. Title Tags
8. Meta Descriptions
9. Heading Structure
10. Content Optimization
11. Image Optimization
12. Internal Linking
13. Keyword Targeting
14. E-E-A-T Signals
15. Content Depth

### Agent 2 (programmatic-seo) — Categories to Cover

All categories from the programmatic-seo SKILL.md:
1. Business Context Assessment
2. Opportunity Assessment (search patterns, volume)
3. Competitive Landscape
4. Applicable Playbooks (from the 12 playbooks)
5. Data Requirements & Sources
6. Template Design Recommendations
7. Internal Linking Architecture
8. Indexation Strategy
9. Quality Checks (pre-launch checklist)
10. Common Mistakes Check

### Agent 3 (seo-geo) — Categories to Cover

All categories from the seo-geo SKILL.md:
1. Current SEO/GEO Status (meta tags, robots, sitemap, schema)
2. AI Bot Access (Googlebot, Bingbot, PerplexityBot, ChatGPT-User, ClaudeBot, GPTBot)
3. Keyword Research
4. GEO Optimization (9 Princeton methods assessment)
5. Traditional SEO Optimization (meta tags, schema, content)
6. Platform-Specific (ChatGPT, Perplexity, Google AI Overview, Copilot, Claude)
7. Schema Markup Assessment
8. Content Structure for AI Crawlers

---

## Final Report Template

Used by Agent 4 (consensus-synthesizer). Merges all 3 individual reports.

```markdown
# Unified SEO Audit Report — {WEBSITE_URL}

## Metadata

| Field | Value |
|-------|-------|
| **Website** | {WEBSITE_URL} |
| **Report Type** | final-report |
| **Timestamp (UTC)** | {YYYY-MM-DD_HH-MM-SS} |
| **Source Reports** | skill-1-seo-audit, skill-2-programmatic-seo, skill-3-seo-geo |
| **Codex Approval** | {PENDING | APPROVED | REVISION {N}} |

---

## Executive Summary

{5-8 sentence overview combining all 3 skill perspectives. MUST include:}
- Overall site health: {CRITICAL | POOR | FAIR | GOOD | EXCELLENT}
- Total findings: {N} ({N} critical, {N} high, {N} medium, {N} low, {N} OK)
- Top 5 priority actions (cross-skill)
- Key strength areas
- Key risk areas

---

## Cross-Skill Consensus

### Agreements

{Issues identified by 2+ skills. List each with source skills.}

| Finding | Identified By | Agreed Severity | Agreed Action |
|---------|---------------|-----------------|---------------|
| {issue} | Skill 1, Skill 3 | {severity} | {action} |

### Conflicts Resolved

| Topic | Skill 1 Says | Skill 2 Says | Skill 3 Says | Resolution | Reasoning |
|-------|-------------|-------------|-------------|------------|-----------|
| {topic} | {view} | {view} | {view} | {decision} | {why} |

### Unique Findings (single skill only)

| Finding | Source Skill | Severity | Included in Final | Reason |
|---------|-------------|----------|-------------------|--------|
| {finding} | Skill {N} | {sev} | YES | {all unique findings are included} |

**RULE: ALL unique findings MUST be included. No information loss.**

---

## All Findings (Unified)

{Merge all findings from all 3 reports. Use the same Finding format as individual reports. Add a "Source" field:}

### Finding {N}: {Title}

| Field | Value |
|-------|-------|
| **Source** | {Skill 1 | Skill 2 | Skill 3 | Multiple} |
| **Severity** | {CRITICAL | HIGH | MEDIUM | LOW} |
| **Category** | {category} |
| **Evidence** | {evidence} |
| **Impact** | {impact} |
| **Recommendation** | {recommendation} |
| **Owner** | {owner} |
| **Effort** | {effort} |
| **Validation** | {how to verify} |

---

## Unified Prioritized Action Plan

| Priority | Finding # | Source | Action | Owner | Effort | Timeline |
|----------|-----------|-------|--------|-------|--------|----------|
| 1 | #{N} | Skill {N} | {action} | {owner} | {effort} | {timeline} |
{Unified across all 3 skills. CRITICAL first, then HIGH, then by effort.}

---

## Unified Validation Test Plan

| Test # | Finding # | Source | Test Description | Expected Result | How to Run |
|--------|-----------|-------|------------------|-----------------|------------|
| T{N} | #{N} | Skill {N} | {test} | {expected} | {how} |

---

## Comparison with Previous Run

{If a previous run exists in ../previous-timestamp/:}

| Metric | Previous ({prev-date}) | Current ({curr-date}) | Delta |
|--------|----------------------|---------------------|-------|
| Total Findings | {N} | {N} | {+/-N} |
| Critical | {N} | {N} | {+/-N} |
| High | {N} | {N} | {+/-N} |
| Medium | {N} | {N} | {+/-N} |
| Low | {N} | {N} | {+/-N} |
| OK Items | {N} | {N} | {+/-N} |
| Health Score | {score} | {score} | {change} |

### Resolved Since Last Run
| Finding | Was | Now |
|---------|-----|-----|
| {finding} | {severity} | OK |

### New Since Last Run
| Finding | Severity |
|---------|----------|
| {finding} | {severity} |

### Unchanged
| Finding | Severity | Notes |
|---------|----------|-------|
| {finding} | {severity} | {still open — why?} |

{If no previous run exists, state: "First run — no comparison available."}

---

## Raw Data Appendix

{Consolidated raw data from all 3 skill reports. Preserve everything.}
```
