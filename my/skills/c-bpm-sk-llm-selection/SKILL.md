---
model: opus
name: c-bpm-sk-llm-selection
description: "LLM selection and orchestration — choose model, assign agent, agent delegation, consensus finding, model selection, MCP discovery, task decomposition. Task-to-LLM matching, orchestration protocol, and conflict resolution."
enforcement: block
intentPatterns: "choose model;;assign agent;;agent delegation;;consensus finding;;task decomposition"
user-invocable: false
---

# LLM Selection & Codex Review Loop

How the Orchestrator selects and delegates tasks to available LLMs, and how the Producer ↔ Codex-as-Judge review loop runs until consensus.

## Available LLMs & Roles

| LLM | Role | Strengths | Use For |
|-----|------|-----------|---------|
| **Claude** | Orchestrator, Primary | Complex reasoning, planning, code review | Orchestration (required), complex tasks, quality-critical work |
| **Codex** | Implementer | Fast code generation, completions | Routine code tasks, quick completions, high-volume generation |
| **Gemini** | Substitute Judge (Codex unreachable only) / Large-Context Reader | Large context, multimodal, alternate Judge when Codex is offline | Large document analysis, image processing, substitute Judge in the review loop ONLY when Codex is unreachable |

## Rules

### Orchestrator Selection
- Orchestrator **MUST** always be Claude (newest model)
- Claude carries the primary workload
- Other LLMs assist but do not orchestrate

### Task Delegation
1. **Default to Claude** for complex, quality-critical, or ambiguous tasks
2. **Use Codex** for straightforward code generation when speed matters
3. **Use Gemini** for large-context or multimodal tasks, or as the substitute Judge in the Producer↔Codex review loop ONLY when Codex is unreachable (network outage, auth failure, binary missing). Never as a co-Judge alongside Codex. Never as a tiebreaker.

## Codex Review Loop (Producer ↔ Judge)

This is the canonical review pattern for every artifact produced in this library
(plan, test design, implementation, audit report — anything an LLM authored).

**Roles**
- **Producer** — the LLM that authored the artifact (plan author, test designer,
  implementer, auditor). The Producer revises its own work when the Judge rejects.
- **Judge** — Codex acts as the LLM-as-a-Judge. The Judge is a single role filled
  by exactly one model at a time.

**Loop**

```
1. Producer submits artifact to the Judge.
2. Judge reviews and either APPROVES or REJECTS with specific reasons.
3. If APPROVED → done; the artifact moves forward.
4. If REJECTED → the artifact returns to the Producer. The Producer revises and
   re-submits to the Judge. Go to step 2.
5. The loop runs until both Producer and Judge agree (consensus). There is no
   cycle cap. There is no abandonment without consensus.
```

**Hard rules (KISS)**

- **No cycle cap.** The loop runs until consensus. "Max N cycles", "cap at N",
  "after N revisions" are forbidden — they were never requested by the user and
  were fabricated by an earlier session (see issue #89). Do not reintroduce them
  in this skill or any downstream artifact.
- **No user inside the loop.** The user is not a fallback Judge. The Judge does
  not "escalate to the user" when the loop runs long. The user is invoked only
  by explicit human direction outside the loop.
- **No third model for tiebreaking.** Convergence happens in practice; do not
  build infrastructure for the deadlock case.
- **Producer revises its own work.** Rejected artifacts go back to whoever
  produced them, not to a different model and not to the user.

**Non-Codex Judge — guard rails**

The fallback chain (Codex → Gemini → next available independent model) exists
ONLY for the case where Codex itself cannot be reached. The following rules are
absolute and must not be relaxed:

- **Substitute, not co-Judge.** Gemini (or any non-Codex Judge) is invoked ONLY
  when Codex is unreachable — network outage, auth failure, binary missing,
  service down. It substitutes for Codex in the Judge role; it is never run
  alongside Codex as a second opinion or co-reviewer.
- **One Judge at a time.** The fallback chain runs sequentially: try Codex; if
  Codex is unreachable, try Gemini; if Gemini is unreachable, try the next
  available independent model. At any given step there is exactly one active
  Judge. Never two Judges concurrently.
- **Never a tiebreaker.** A non-Codex Judge is NEVER invoked to break a deadlock
  between Producer and Codex. If Codex is reachable and rejects, the Producer
  revises and re-submits to Codex — Gemini (or any other model) is not called
  as a tiebreaker, arbiter, mediator, or second opinion. The same rule applies
  in reverse if Gemini is the active Judge: Codex is not called to break a tie
  with Gemini.

This pattern is referenced by `c-bpm-sk-skill-creator`, `c-bpm-sk-skill-optimizer`,
`c-bpm-cm-openissues-team`, and every other skill or command that runs a Codex
review gate. It is the canonical definition; downstream skills must remain
consistent with it.

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
- Skipping the Codex Judge review at a mandatory gate
- Imposing an artificial cycle cap on the Producer ↔ Codex loop
- Escalating a Codex rejection to the user instead of returning the artifact to the Producer
- Inviting a third model alongside Codex to break a tie
- Running Gemini (or any non-Codex Judge) as a co-Judge or second opinion while Codex is reachable
- Not checking LLM availability before assignment
