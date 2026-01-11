# Skill S13 – LLM Selection & Consensus Standard

## Goal

Define how the Orchestrator selects and delegates tasks to available LLMs, and how conflicts between agents are resolved through consensus finding.

## When to Use

- At the start of any multi-agent workflow to determine LLM availability.
- When assigning tasks to agents to choose the optimal LLM.
- When two agents disagree on an approach and consensus is needed.

## Available LLMs & Roles

| LLM | Role | Strengths | Use For |
|-----|------|-----------|---------|
| **Claude** | Orchestrator, Primary | Complex reasoning, planning, code review, nuanced decisions | Orchestration (required), complex tasks, quality-critical work |
| **Codex** | Implementer | Fast code generation, completions, boilerplate | Routine code tasks, quick completions, high-volume generation |
| **Gemini** | Consensus Finder | Large context, mediation, multimodal | Conflict resolution, large document analysis, image processing |

## Rules

### Orchestrator Selection
- The Orchestrator **MUST** always be Claude (newest available model).
- Claude carries the primary workload due to superior reasoning capabilities.
- Other LLMs assist but do not orchestrate.

### Task Delegation
1. **Default to Claude** for complex, quality-critical, or ambiguous tasks.
2. **Use Codex** for straightforward code generation when speed matters.
3. **Use Gemini** for consensus finding, large context processing, or multimodal tasks.

### Efficiency vs Quality
- **High stakes / complex**: Always Claude.
- **Routine / high volume**: Consider Codex for efficiency.
- **Conflict resolution**: Gemini as neutral mediator.

## Consensus Finding Workflow

When Agent A (planner) and Agent B (reviewer) disagree:

```
1. A produces plan
2. B reviews and raises concerns
3. If conflict:
   a. Gemini (C) receives both positions
   b. C analyzes arguments objectively
   c. C proposes resolution or compromise
   d. If consensus found → proceed
   e. If no consensus → escalate to Orchestrator (Claude)
4. Orchestrator makes final decision
```

## LLM Availability Handoff

The Orchestrator must publish LLM availability at planning start:

```
## LLM Availability Handoff
- Claude: ✅ Available (orchestrator)
- Codex: ✅ Available
- Gemini: ✅ Available / ❌ Not available
```

## Checklist

- [ ] Orchestrator is Claude (newest model).
- [ ] LLM Availability Handoff is published.
- [ ] Tasks are assigned to appropriate LLMs based on strengths.
- [ ] Consensus finding workflow is used for conflicts.
- [ ] Efficiency and quality are balanced appropriately.

## Success Criteria

- No LLM is used outside its designated role.
- Conflicts are resolved efficiently through consensus finding.
- Claude handles orchestration and complex tasks.
- Overall workflow is efficient without sacrificing quality.

## Common Failure Modes

- Using a secondary LLM for orchestration (always use Claude).
- Over-delegating complex tasks to Codex for speed.
- Skipping consensus finding and letting conflicts block progress.
- Not checking LLM availability before task assignment.
