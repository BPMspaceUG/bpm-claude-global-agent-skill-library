Run `/my-seo-auditor` for https://ico-cert.org

Website: https://ico-cert.org
Website slug: ico-cert-org

Load and follow the my-seo-auditor skill (`~/.claude/skills/my-seo-auditor/SKILL.md`) exactly:

1. Pre-flight checks (git pull skills, security pass/fail gate)
2. `TeamCreate`, then spawn 4 agents via `Task` tool (all `model="opus"`, `mode="plan"`); consensus agent deferred to Phase 3
3. Phase 1: Run 3 skill agents in parallel (seo-audit, programmatic-seo, seo-geo)
4. Phase 2: Codex approves each individual report
5. Phase 2b: Codex approves test designs
6. Phase 3: Consensus synthesizer merges all 3 into final report
7. Phase 4: Codex approves final report
8. Phase 5: Create INDEX.md, verify all files, shutdown agents, TeamDelete

Reports go to: `reports/ico-cert-org/{TIMESTAMP}/`

**Codex constraint:** Codex MUST be invoked ONLY via `codex exec --skip-git-repo-check "<prompt>"`. Never any other way.

Use the standardized report templates from the skill. No information loss.
