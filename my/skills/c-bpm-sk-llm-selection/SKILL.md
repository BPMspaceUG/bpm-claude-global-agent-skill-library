---
model: opus
name: c-bpm-sk-llm-selection
description: "LLM selection and orchestration — choose model, assign agent, agent delegation, consensus finding, model selection, MCP discovery, task decomposition. Task-to-LLM matching, orchestration protocol, and conflict resolution."
enforcement: block
intentPatterns: "choose model;;assign agent;;agent delegation;;consensus finding;;task decomposition"
user-invocable: false
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

## Orchestration Protocol

### MCP Discovery

At planning start, discover all MCP servers in the current session:
1. Determine which servers are relevant to the current objective
2. Publish **MCP Availability Handoff** before delegating tasks

### MCP Availability Handoff

```
## MCP Availability Handoff
- Server A: Available (relevant)
- Server B: Available (not relevant to current task)
- Server C: Not available
```

### Task Decomposition

Translate user goals into a structured task plan:
1. Sequenced task list with acceptance criteria per task
2. Agent/LLM assignment per task (using delegation rules above)
3. Scope boundaries — no overlapping or conflicting tasks
4. Assumptions block — versions, environment, dependencies
5. Expected completion order
6. Follow `c-bpm-sk-milestone-type` for issue lifecycle and type enforcement when creating or tracking issues

All implementers MUST rely on Orchestrator handoffs and may not probe MCP servers independently.

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
