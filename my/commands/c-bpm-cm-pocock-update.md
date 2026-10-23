---
name: c-bpm-cm-pocock-update
description: "Update Matt Pocock's skills plugin and unlock every skill for model invocation — pocock update, update pocock skills, unlock pocock skills, remove disable-model-invocation, pocock skills not callable. Runs the plugin update, then strips the invocation lock from every installed SKILL.md."
allowed-tools: Bash
argument-hint: "[--check] [--no-update]"
---

# /c-bpm-cm-pocock-update — Update and unlock Matt Pocock's skills

Arguments passed by the user: $ARGUMENTS

Matt Pocock's plugin (`mattpocock-skills@mattpocock`) ships most skills with
`disable-model-invocation: true`, so Claude cannot call `to-spec`, `to-tickets`,
`implement-spec`, `retro`, `triage`, `wayfinder` and others on its own. Every
plugin update restores that line in the installed copy.

The logic lives in one script, installed by `c-bpm-cm-library-pull` together
with the library's hooks: `~/.claude/hooks/c-bpm-hk-skills-refresh.sh`. Its
SessionStart hook already unlocks at every start and refreshes plugin and
library at most once a day in the background. This command is the manual,
immediate path.

## Procedure

Map the arguments and run exactly one command with Bash:

| Arguments | Command |
|---|---|
| none | `~/.claude/hooks/c-bpm-hk-skills-refresh.sh update` |
| `--check` | `~/.claude/hooks/c-bpm-hk-skills-refresh.sh check` |
| `--no-update` | `~/.claude/hooks/c-bpm-hk-skills-refresh.sh unlock` |

If the script is missing, run `c-bpm-cm-library-pull` first, then retry once.

## Report

Print the table verbatim. After `update`, or when `unlocked this run` is above
0, add one line: restart Claude Code to load the change. Nothing else. If the
plugin update failed, the table names the reason; do not retry with other
flags.
