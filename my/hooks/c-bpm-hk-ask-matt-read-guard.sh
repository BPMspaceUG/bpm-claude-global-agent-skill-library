#!/usr/bin/env bash
# c-bpm-hk-ask-matt-read-guard.sh — Stop hook: an answer whose next-step line
# says "ask-matt empfiehlt" is sent back once if ask-matt was not read in this
# session. The skill c-bpm-sk-next-step demands that read; a session that wrote
# the line from memory recommended the wrong step (no /code-review, no /retro).
#
# Read counts as: a tool call whose input names ask-matt/SKILL.md (Read, Bash),
# a Skill call of mattpocock-skills:ask-matt, or Robert invoking /ask-matt
# (the transcript then holds the skill's "Base directory … /ask-matt" message).
# Mentions inside other text (the next-step skill names the path) do not count.
#
# Wired by my/hooks/c-bpm-hooks.json (Stop). Always exits 0; blocks via JSON.

set -uo pipefail

INPUT="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

# One block per stop: Claude Code sets stop_hook_active on the retry.
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

MSG="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty')"
case "$MSG" in *"ask-matt empfiehlt"*) ;; *) exit 0 ;; esac

TP="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')"
[ -n "$TP" ] && [ -f "$TP" ] || exit 0

# Count, not grep -q: an early grep exit kills jq with SIGPIPE, and pipefail
# would turn a hit into a miss.
HITS="$(grep -F 'ask-matt' "$TP" | jq -R -r '
    fromjson?
    | (select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | tostring),
      (select(.type == "user") | .message.content
        | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end
        | select(test("Base directory for this skill: [^\\n]*/ask-matt\\b"))
        | "skill-invoked")
  ' 2>/dev/null | grep -cE 'ask-matt/SKILL\.md|mattpocock-skills:ask-matt|^skill-invoked$')"
[ "${HITS:-0}" -gt 0 ] && exit 0

jq -n '{decision: "block", reason: "The next-step line says \"ask-matt empfiehlt\", but ask-matt was not read in this session. Read ~/.claude/plugins/marketplaces/mattpocock/skills/engineering/ask-matt/SKILL.md (skill c-bpm-sk-next-step), place the situation on its map, and rewrite the closing line from it."}'
exit 0
