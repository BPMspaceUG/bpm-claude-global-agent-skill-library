---
name: c-bpm-sk-next-step
description: "End every answer with exactly one 'Nächster Schritt' line chosen via ask-matt: either the Pocock skill to type next or 'Warten' with the next watchdog check time. Use before finishing any answer, and whenever background agents, workflows, monitors or tmux Claude sessions are running."
---

# Next step line

Every answer ends with **exactly one** next-step line. The owner asked for it;
it is not an unsolicited suggestion. The line is written in the language of the
conversation (German for Robert); the templates below are the German wording.

## Choose the step with ask-matt, not from memory

Before writing the line, read
`~/.claude/plugins/marketplaces/mattpocock/skills/engineering/ask-matt/SKILL.md`
(once per session; `PHASE-BOUNDARIES.md` next to it when at a phase boundary)
and place the situation on its map: main flow (grill → spec → tickets →
implement → retro), on-ramp (triage, diagnosing-bugs, wayfinder), or phase
boundary (continue, clear, handoff, compact). Read a skill's SKILL.md before
recommending it.

## The two forms

No actor labels such as "(ich)", "(Robert)", "(du)" or "(AI)". The line always
addresses the user directly, in the imperative.

    **Nächster Schritt:** `/mattpocock-skills:<skill>` eintippen. <why, per ask-matt, one sentence>
    **Nächster Schritt:** Warten. Nächster Check um <HH:MM> (Job <id>), bis dahin musst du nichts tun.

"Warten" is preceded by one status line:

    **Gerade läuft:** <which agents/sessions, what they work on, state at the last check>

Rules:

- The skill in the first form is the one ask-matt proposes for the current situation.
- If a question or decision is waiting for the user, the line is
  `**Nächster Schritt:** <Frage> beantworten.`
- If you can take the step yourself, take it now instead of ending with an
  offer. Write the line afterwards.
- Never a second action line ("Was du jetzt tust" or similar). "Gerade läuft"
  is status only.
- "Warten" is a full next step: the watchdog loop works, the user waits. Do not
  start anything just because an answer is ending.
- Never end open ("melde dich") or with status and no direction.

## Running agents get a real watchdog loop

As soon as anything runs in the background (subagents, workflows, monitors,
Claude sessions in tmux such as `/oi_loop`), create a recurring check with
`CronCreate` **before the answer ends**, about every 15 minutes on odd minutes
(`7,22,37,52 * * * *`). A promise in the text is not a check, and neither is a
completion notice that never arrives.

Each check verifies that the agents **are doing something**, not only that they exist:

1. `ListAgents`: status of every watched session or agent (busy/idle/waiting).
2. For tmux sessions, `tmux capture-pane -p -t <pane> | tail -40`: is it stuck
   on a question, a permission dialog, a menu, an error, or "Should I continue?"?
3. Progress since the last check: new commits (`git log --since`), issue
   activity, growing logs. An agent that is "busy" and has not moved for two
   checks in a row counts as hung.
4. Intervene instead of reporting: answer a pointless question yourself (via
   `SendMessage` or `tmux send-keys`) following the memory
   `autonomous-runs-never-stop.md`; restart a dead agent. Ask the user only for
   a genuine owner decision.
5. When everything is done: remove the job with `CronDelete` and write the
   normal next-step line.

Every check output ends with the time of the next check, taken from the
`CronCreate`/`CronList` result, not from the cron expression (the scheduler
shifts jobs). Cron jobs live only in this session and expire after 7 days; when
the session ends the watchdog is gone, so say so.
