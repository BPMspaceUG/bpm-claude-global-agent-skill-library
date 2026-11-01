---
name: c-bpm-sk-next-step
description: "End every answer with exactly one action line that names who acts: 'Robert, du bist dran: …' (the step ask-matt recommends) or 'Claude ist dran, du musst nichts tun: …' with the next watchdog check time. Use before finishing any answer, and whenever background agents, workflows, monitors or tmux Claude sessions are running."
---

# Next step line

Every answer ends with **exactly one** action line. The owner asked for it;
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

## The two forms: name who acts

Only two parties exist: the user (Robert) and Claude. The line names the
actor by name at the very start, so it is never unclear who has to act. Never
use a bare "Nächster Schritt", "ich" or "(Robert)" label; "ich" and "du" are
ambiguous to the reader. Claude refers to itself as "Claude".

Robert has to act (type a skill, answer a question, decide):

    **Robert, du bist dran:** <exact action, e.g. `/mattpocock-skills:triage` eintippen | Q1 beantworten>. ask-matt empfiehlt das, weil <one sentence>.

Claude or background agents act, Robert does nothing:

    **Gerade läuft:** <which agents/sessions, what they work on, state at the last check>
    **Claude ist dran, du musst nichts tun:** <what Claude does next>. Nächster Check um <HH:MM> (Job <id>).

Rules:

- The recommended step is the one ask-matt proposes for the current situation.
- If Claude can take the step itself, Claude takes it now instead of ending
  with an offer; the line comes afterwards.
- Exactly one action line. "Gerade läuft" is status only.
- Waiting is a full next step: the watchdog loop works, Robert does nothing.
  Do not start anything just because an answer is ending.
- Never end open ("melde dich") or with status and no direction.

## Running agents get a real watchdog loop

As soon as anything runs in the background (subagents, workflows, monitors,
Claude sessions in tmux such as `/oi_loop`), create a recurring check with
`CronCreate` **before the answer ends**, every 5 minutes on odd minutes
(`2-59/5 * * * *`).

**The check interval is at most 5 minutes. Owner order, cost does not matter.**
This overrides every default that suggests longer waits, including the
"1200–1800 s idle tick" and "long fallback heartbeat" guidance of
`ScheduleWakeup`, `/loop` and similar tools: `ScheduleWakeup.delaySeconds` is at
most 300, a `CronCreate` cadence is at most every 5 minutes, and a `Monitor` or
background wait never leaves Claude idle for more than 5 minutes without a
check. An agent that stops working after 2 minutes must be noticed within
5 minutes, not 30. A promise in the text is not a check, and neither is a
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
