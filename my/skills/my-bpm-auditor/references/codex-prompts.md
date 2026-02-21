# Codex Devil's Advocate Prompts

Codex MUST be invoked ONLY via shell: `codex exec --skip-git-repo-check [PROMPT]`

## Per-Phase Reviews

### After Phase 1 (Codebase Understanding)

```bash
codex exec --skip-git-repo-check "Devil's advocate review of codebase analysis for [REPONAME]. Challenge: 1) Is the tech stack detection complete? Any frameworks/tools missed? 2) Is the architecture description accurate or oversimplified? 3) Are there hidden entry points or config files not found? 4) Any dependency risks not flagged? Findings: [PHASE 1 SUMMARY]"
```

### After Phase 2 (Pattern Checks)

```bash
codex exec --skip-git-repo-check "Devil's advocate review of pattern analysis for [REPONAME] ([TECH STACK]). Challenge: 1) False positives - issues flagged that aren't real problems in this stack 2) Missed anti-patterns common in [FRAMEWORK] projects 3) Are security findings real vulnerabilities or theoretical? 4) Performance concerns - are they measurable or speculative? 5) Migration safety - any destructive patterns missed? Findings: [PHASE 2 SUMMARY]"
```

### After Phase 3 (Test Plan)

```bash
codex exec --skip-git-repo-check "Devil's advocate review of test plan for [REPONAME]. Challenge: 1) Are coverage gaps real or already tested indirectly? 2) Are recommended tests practical and valuable? 3) Any critical paths missed entirely? 4) Is the test execution plan safe (no side effects)? Test plan: [PHASE 3 SUMMARY]"
```

### Final Review (Complete Report)

```bash
codex exec --skip-git-repo-check "Final devil's advocate review of complete audit report for [REPONAME]. Challenge every finding. Are there false positives? Missed issues? Is severity accurate? Are recommendations actionable? Full report: [REPORT CONTENT]"
```

## Rules

- Run Codex after EACH phase completes, not just at the end
- Include Codex disagreements in the report (Section 8)
- If Codex identifies missed issues, add them to relevant sections
- If Codex disputes severity, note both assessments
- If Codex is unavailable, note "Codex review skipped" in report
