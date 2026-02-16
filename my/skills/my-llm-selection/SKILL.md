---
name: my-llm-selection
description: Guide for selecting and delegating tasks to LLMs and resolving conflicts through consensus finding. Use at the start of multi-agent workflows, when assigning tasks to agents, or when consensus is needed between disagreeing agents. Derived from S13.
---

# LLM Selection & Consensus

How the Orchestrator selects and delegates tasks to available LLMs, and how conflicts between agents are resolved through consensus finding.

## Available LLMs & Roles

| LLM | Role | Strengths | Use For |
|-----|------|-----------|---------|
| **Claude** | Orchestrator, Primary | Complex reasoning, planning, code review | Orchestration (required), complex tasks, quality-critical work |
| **Codex** | Implementer | Fast code generation, completions | Routine code tasks, quick completions, high-volume generation |
| **Gemini** | Consensus Finder | Large context, mediation, multimodal | Conflict resolution, large document analysis, image processing |

## Rules

### Orchestrator Selection
- Orchestrator **MUST** always be Claude (newest model)
- Claude carries the primary workload
- Other LLMs assist but do not orchestrate

### Task Delegation
1. **Default to Claude** for complex, quality-critical, or ambiguous tasks
2. **Use Codex** for straightforward code generation when speed matters
3. **Use Gemini** for consensus finding, large context, or multimodal tasks

## Consensus Finding Workflow

```
1. Agent A produces plan
2. Agent B reviews and raises concerns
3. If conflict:
   a. Gemini receives both positions
   b. Gemini analyzes objectively
   c. Gemini proposes resolution
   d. If consensus → proceed
   e. If no consensus → Orchestrator (Claude) decides
4. Orchestrator makes final decision
```

## LLM Availability Handoff

```
## LLM Availability Handoff
- Claude: Available (orchestrator)
- Codex: Available
- Gemini: Available / Not available
```

## Success Criteria

- No LLM used outside its designated role
- Conflicts resolved efficiently through consensus
- Claude handles orchestration and complex tasks
- Efficient workflow without sacrificing quality

## Common Failure Modes

- Using secondary LLM for orchestration
- Over-delegating complex tasks to Codex for speed
- Skipping consensus finding, blocking progress
- Not checking LLM availability before assignment
