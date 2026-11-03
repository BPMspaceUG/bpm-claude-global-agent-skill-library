#!/usr/bin/env bash
# c-bpm-hk-ask-matt-after-clear.sh — after /clear, ask ask-matt what Robert
# has to do next, and show the answer immediately.
#
# Robert's standing rule: after /clear he must be told which command to type
# next. A SessionStart hook cannot make the session answer by itself, so this
# hook asks a headless `claude -p` run instead: it gets the ask-matt router
# (SKILL.md + PHASE-BOUNDARIES.md), the tail of the conversation that was just
# cleared and the repo state, and returns one action line. The line is shown
# to Robert (systemMessage) and handed to the new session (additionalContext).
#
# Wired by my/hooks/c-bpm-hooks.json (SessionStart, matcher "clear"),
# installed by c-bpm-cm-library-pull. Always exits 0.

set -uo pipefail

LOG="${HOME}/.claude/hooks/c-bpm-hk-ask-matt-after-clear.log"
INPUT="$(cat)"
log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG" 2>/dev/null; }

# Never recurse: the headless run below starts a session of its own.
if [ -n "${C_BPM_ASK_MATT_CHILD:-}" ]; then exit 0; fi
command -v jq >/dev/null 2>&1 || { log "jq missing"; exit 0; }

SRC="$(printf '%s' "$INPUT" | jq -r '.source // empty')"
[ "$SRC" = "clear" ] || exit 0
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty')"
TP="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
[ -n "$CWD" ] || CWD="$PWD"

ASK_DIR="${C_BPM_ASK_MATT_DIR:-}"
if [ -z "$ASK_DIR" ]; then
  ASK_DIR="$(find "$HOME/.claude/plugins" -path '*engineering/ask-matt/SKILL.md' -printf '%T@ %h\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)"
fi
if [ -z "$ASK_DIR" ] || [ ! -f "$ASK_DIR/SKILL.md" ]; then
  log "ask-matt SKILL.md not found"
  jq -n '{systemMessage: "ask-matt: SKILL.md nicht gefunden, kein Rat nach /clear möglich."}'
  exit 0
fi

# The conversation that was just cleared: newest other transcript in the same
# project directory.
PREV=""
if [ -n "$TP" ]; then
  PDIR="$(dirname "$TP")"
  PREV="$(ls -t "$PDIR"/*.jsonl 2>/dev/null | grep -v "/${SID}.jsonl$" | head -1)"
fi
CONV=""
if [ -n "$PREV" ] && [ -f "$PREV" ]; then
  CONV="$(tail -n 400 "$PREV" | jq -r '
      select(.type == "user" or .type == "assistant")
      | .type as $t
      | (.message.content
         | if type == "string" then .
           else ([.[]? | select(.type == "text") | .text] | join("\n")) end) as $txt
      | select(($txt | length) > 0)
      | select(($txt | test("^<(local-command|command-name|task-notification|system-reminder)") | not))
      | (if $t == "user" then "ROBERT: " else "CLAUDE: " end) + ($txt | .[0:1500])
    ' 2>/dev/null | tail -c 14000)"
fi

GIT=""
if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT="Repo: $(git -C "$CWD" remote get-url origin 2>/dev/null)
Branch: $(git -C "$CWD" branch --show-current 2>/dev/null)
Last commits:
$(git -C "$CWD" log -5 --format='%h %cr %s' 2>/dev/null)
Working tree:
$(git -C "$CWD" status -s 2>/dev/null | head -20)"
fi

PROMPT="You are the ask-matt router. Robert just typed /clear in a Claude Code session.
Working directory: $CWD
$GIT

Decide what Robert has to do next, using ONLY the ask-matt router below
(main flow, on-ramps, phase boundaries). Base it on the conversation that was
just cleared. If it is empty or unclear, recommend the entry point that fits
the repo state.

Answer in German with exactly one line and nothing else, in this form:
**Robert, du bist dran:** \`/mattpocock-skills:<skill> <argument if useful>\` eintippen. ask-matt empfiehlt das, weil <one sentence, concrete to this situation>.
If what is pending is a question or decision for Robert instead of a skill,
name it concretely in the same form (\"<Frage> beantworten\").

===== ask-matt SKILL.md =====
$(cat "$ASK_DIR/SKILL.md")

===== ask-matt PHASE-BOUNDARIES.md =====
$(cat "$ASK_DIR/PHASE-BOUNDARIES.md" 2>/dev/null)

===== Conversation just cleared (tail) =====
${CONV:-(none found)}"

WORK="${HOME}/.cache/c-bpm-ask-matt"
mkdir -p "$WORK"
ANSWER="$(cd "$WORK" && printf '%s' "$PROMPT" | C_BPM_ASK_MATT_CHILD=1 timeout 150 \
  "${C_BPM_ASK_MATT_CLAUDE:-claude}" -p --tools "" --no-session-persistence 2>>"$LOG")"
rc=$?
ANSWER="$(printf '%s' "$ANSWER" | grep -v '^\s*$' | tail -1)"
log "rc=$rc prev=${PREV:-none} answer=${ANSWER:0:300}"

if [ $rc -ne 0 ] || [ -z "$ANSWER" ]; then
  jq -n --arg rc "$rc" '{systemMessage: ("ask-matt nach /clear fehlgeschlagen (rc " + $rc + "), Log: ~/.claude/hooks/c-bpm-hk-ask-matt-after-clear.log")}'
  exit 0
fi

jq -n --arg a "$ANSWER" '{
  systemMessage: ("ask-matt nach /clear: " + $a),
  hookSpecificOutput: {hookEventName: "SessionStart", additionalContext:
    ("After /clear, ask-matt already told Robert his next step: " + $a +
     " If Robert asks what to do, repeat it; do not invent a different step.")}}'
exit 0
