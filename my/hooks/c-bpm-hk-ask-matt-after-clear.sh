#!/usr/bin/env bash
# c-bpm-hk-ask-matt-after-clear.sh — after /clear, show Robert the last
# "next step" line of the conversation he just cleared. Instant, no model run.
#
# Robert's standing rule: after /clear he must be told what to type next.
# Every answer already ends with that line (skill c-bpm-sk-next-step, chosen
# with ask-matt): "**Robert, du bist dran:** …" or "**Claude ist dran, …:** …".
# So the decision has already been made; this hook only caches and replays it.
#
# Modes (wired by my/hooks/c-bpm-hooks.json, installed by c-bpm-cm-library-pull):
#   save   Stop -> take the last action line of the answer that just ended and
#          write it to the cache (one file per tmux pane, one per directory).
#   clear  SessionStart(clear) -> read the cache (pane first, then directory;
#          fallback: scan the cleared transcript) and show the line to Robert
#          (systemMessage) and to the new session (additionalContext). If the
#          line is "Robert, du bist dran:" with a `/command`, also type that
#          command into the tmux pane's prompt (no Enter): prefilled. It also
#          writes session-<id>, which the host status line shows below the
#          prompt until the first answer of the new session ends.
#
# Cache: ~/.cache/c-bpm-next-step/. Log: ~/.claude/hooks/c-bpm-hk-ask-matt-after-clear.log.
# Always exits 0.

set -uo pipefail

MODE="${1:-clear}"
LOG="${HOME}/.claude/hooks/c-bpm-hk-ask-matt-after-clear.log"
CACHE="${HOME}/.cache/c-bpm-next-step"
INPUT="$(cat)"
log() { printf '%s %s %s\n' "$(date -Is)" "$MODE" "$*" >>"$LOG" 2>/dev/null; }
command -v jq >/dev/null 2>&1 || { log "jq missing"; exit 0; }

if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 262144 ]; then
  tail -c 131072 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
[ -n "$CWD" ] || CWD="$PWD"
TP="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty')"

# Cache keys: the tmux pane identifies Robert's terminal across /clear; the
# directory is the fallback outside tmux.
PANE_KEY=""
if [ -n "${TMUX_PANE:-}" ]; then
  PANE_KEY="$CACHE/pane-$(printf '%s' "$TMUX_PANE" | tr -cd 'A-Za-z0-9')"
fi
DIR_KEY="$CACHE/dir-$(printf '%s' "$CWD" | md5sum | cut -c1-16)"

# The last action line in a text: "**Robert, du bist dran:** …" or
# "**Claude ist dran, du musst nichts tun:** …".
last_line() {
  grep -E '\*\*(Robert, du bist dran|Claude ist dran[^*]*):\*\*' | tail -1 | sed 's/^[[:space:]]*//'
}

# Assistant texts of a transcript, oldest first.
transcript_text() {
  [ -f "$1" ] || return 0
  tail -n 400 "$1" | jq -r '
      select(.type == "assistant")
      | .message.content
      | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end
    ' 2>/dev/null
}

write_cache() {
  mkdir -p "$CACHE" || return 0
  local f
  for f in "$PANE_KEY" "$DIR_KEY"; do
    [ -n "$f" ] || continue
    printf '%s\n' "$1" >"$f.tmp" && mv "$f.tmp" "$f"
  done
}

case "$MODE" in
  save)
    # The first answer after /clear ends the status-line hint of this session.
    [ -n "$SID" ] && rm -f "$CACHE/session-$SID"
    LINE="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' | last_line)"
    [ -n "$LINE" ] || LINE="$(transcript_text "$TP" | last_line)"
    if [ -n "$LINE" ]; then
      write_cache "$LINE"
      log "saved pane=${TMUX_PANE:-none} cwd=$CWD line=${LINE:0:200}"
    fi
    exit 0
    ;;
esac

SRC="$(printf '%s' "$INPUT" | jq -r '.source // empty')"
[ "$SRC" = "clear" ] || exit 0

LINE="" FROM=""
for f in "$PANE_KEY" "$DIR_KEY"; do
  if [ -n "$f" ] && [ -s "$f" ]; then LINE="$(head -1 "$f")"; FROM="$f"; break; fi
done

# Fallback: the cleared conversation is the newest other transcript in the
# same project directory.
if [ -z "$LINE" ] && [ -n "$TP" ]; then
  PREV="$(ls -t "$(dirname "$TP")"/*.jsonl 2>/dev/null | grep -v "/${SID}.jsonl$" | head -1)"
  if [ -n "$PREV" ]; then
    LINE="$(transcript_text "$PREV" | last_line)"
    FROM="$PREV"
  fi
fi
log "from=${FROM:-none} line=${LINE:0:200}"

if [ -z "$LINE" ]; then
  jq -n '{systemMessage: "Nach /clear: kein gespeicherter Hinweis gefunden. Frag nach dem nächsten Schritt."}'
  exit 0
fi

# Status-line hint: Claude Code draws the status line below the prompt. The
# host status line (/usr/local/bin/claude-statusline.sh) prints
# $CACHE/session-<session_id> as a second line until the first answer ends
# (save mode removes it). Stale files go after two days.
if [ -n "$SID" ] && mkdir -p "$CACHE"; then
  printf '%s\n' "$LINE" >"$CACHE/session-$SID"
  find "$CACHE" -maxdepth 1 -name 'session-*' -mtime +2 -delete 2>/dev/null
fi

# Prefill: Claude Code shows systemMessage above the /clear, far from the
# prompt. If the line tells Robert to type a slash command, type it into his
# prompt (no Enter), so it waits right below. Only inside tmux; detached, so
# the hook returns at once and the prompt is ready when the keys arrive.
CMD=""
case "$LINE" in
  '**Robert, du bist dran:**'*)
    CMD="$(printf '%s' "$LINE" | sed -n 's/^[^`]*`\(\/[^`]*\)`.*/\1/p')" ;;
esac
if [ -n "$CMD" ] && [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then
  DELAY="${C_BPM_PREFILL_DELAY:-1.5}"
  setsid bash -c 'sleep "$1"; tmux send-keys -t "$2" -l "$3"' _ "$DELAY" "$TMUX_PANE" "$CMD" \
    </dev/null >/dev/null 2>&1 &
  log "prefill pane=$TMUX_PANE cmd=$CMD"
fi

jq -n --arg a "$LINE" '{
  systemMessage: ("Letzter Hinweis vor /clear: " + $a),
  hookSpecificOutput: {hookEventName: "SessionStart", additionalContext:
    ("Before /clear, the last answer ended with this next-step line, and Robert has been shown it: " + $a +
     " If Robert asks what to do, start from it; it may be outdated if it named work of the cleared session.")}}'
exit 0
