#!/usr/bin/env bash
# c-bpm-hk-agent-cleanup-guard.sh — close agents that have reported, and show
# Robert what is still running.
#
# Robert's standing rule: an agent that has reported back is litter. It must be
# stopped, and he must be able to see what is still in flight.
#
# Modes (wired by my/hooks/c-bpm-hooks.json, installed by c-bpm-cm-library-pull):
#   idle   TeammateIdle -> {"continue": false}: Claude Code stops the teammate
#          itself. (Exit 2 would make the teammate KEEP WORKING — that was the
#          bug of the first version.)
#   stop   Stop -> reads background_tasks. Teammates and shells still open get
#          one continuation asking for TaskStop by id; a status line listing
#          everything in flight is always shown to the user. Never continues a
#          second time in a row (stop_hook_active), so it cannot loop.
#   start  SessionStart -> /clear keeps teammates alive, so demand a sweep.
#
# Contract source: https://code.claude.com/docs/en/hooks.md (TeammateIdle,
# Stop input and decision control). Always exits 0.

set -uo pipefail

MODE="${1:-stop}"
LOG="${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.log"
INPUT="$(cat)"

if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 262144 ]; then
  tail -c 131072 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
printf '%s %s %s\n' "$(date -Is)" "$MODE" "$(printf '%s' "$INPUT" | tr '\n' ' ')" >>"$LOG" 2>/dev/null

case "$MODE" in
  idle)
    who="$(printf '%s' "$INPUT" | jq -r '.teammate_name // .agent_id // "teammate"' 2>/dev/null)"
    jq -n --arg who "${who:-teammate}" '{
      continue: false,
      stopReason: ("Agent cleanup: teammate " + $who + " finished its turn and was stopped.")
    }'
    ;;

  start)
    jq -n '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext:
      "AGENT SWEEP REQUIRED: /clear and a session restart do NOT stop teammates spawned earlier -- they keep running under this same session name while your context is empty. Before you answer the user, call ListAgents once and TaskStop every teammate or named agent it lists, including ones you have no memory of spawning. Never touch the peer interactive, Remote Control or cloud sessions in that list: those are Robert'"'"'s own terminals."}}'
    ;;

  stop)
    printf '%s' "$INPUT" | jq -c '
      (.background_tasks // []) as $all
      | [ $all[] | select(.type != "monitor") ] as $tasks
      | if ($tasks | length) == 0 then empty else
          ([ $tasks[] | select(.type == "teammate" or .type == "shell") ]) as $open
          | ($tasks | group_by(.type) | map("\(length) \(.[0].type)") | join(", ")) as $summary
          | { systemMessage: ("Still running: " + $summary + " — " +
                ([ $tasks[] | "\(.id) \(.description // "" | .[0:60])" ] | join("; "))) }
          + ( if (.stop_hook_active != true) and (($open | length) > 0) then
                { hookSpecificOutput: { hookEventName: "Stop", additionalContext:
                  ("Agent cleanup: these tasks are still open: " +
                   ([ $open[] | "\(.type) \(.id) (\(.description // "" | .[0:80]))" ] | join("; ")) +
                   ". Call TaskStop with each id whose result is already in or no longer needed. If one is genuinely still working, say so in one line naming it, and stop it as soon as its result arrives.") } }
              else {} end )
        end' 2>/dev/null
    ;;
esac
exit 0
