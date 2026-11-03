#!/usr/bin/env bash
# tests/live/tmux-claude.sh - drive a real Claude Code session in tmux for live
# checks of hooks and mods. Waits on what the pane shows, never a fixed sleep.
#
#   tmux-claude.sh start <name> [cols] [dir] [cmd...]  detached session (default: 200 cols, $PWD, claude)
#   tmux-claude.sh send <name> <text> [--enter]        type text literally; --enter submits it
#   tmux-claude.sh wait <name> <regex> [seconds]       until the pane matches (ERE); default 60 s
#   tmux-claude.sh capture <name> [lines]              last lines of the pane (default 40)
#   tmux-claude.sh kill <name>
#
# Example: start t; wait t '❯'; send t /clear --enter; wait t 'Last recommendation'
set -euo pipefail

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ $# -ge 2 ] || usage
op="$1" name="$2"; shift 2

case "${op}" in
  start)
    cols="${1:-200}" dir="${2:-$PWD}"; shift $(( $# < 2 ? $# : 2 ))
    [ $# -gt 0 ] || set -- claude
    tmux new-session -d -s "${name}" -x "${cols}" -y 50 -c "${dir}" "$@"
    ;;
  send)
    [ $# -ge 1 ] || usage
    tmux send-keys -t "${name}" -l "$1"
    [ "${2:-}" = "--enter" ] && tmux send-keys -t "${name}" Enter
    ;;
  wait)
    [ $# -ge 1 ] || usage
    regex="$1" secs="${2:-60}" end=$((SECONDS + ${2:-60}))
    while [ "${SECONDS}" -lt "${end}" ]; do
      # Capture first: grep -q on a pipe can SIGPIPE tmux, and pipefail turns
      # that hit into a miss.
      pane="$(tmux capture-pane -p -t "${name}")"
      grep -qE -- "${regex}" <<<"${pane}" && exit 0
      sleep 0.5
    done
    echo "timeout after ${secs}s waiting for /${regex}/ in ${name}; pane:" >&2
    tmux capture-pane -p -t "${name}" | grep -v '^[[:space:]]*$' | tail -20 >&2
    exit 1
    ;;
  capture) tmux capture-pane -p -t "${name}" | grep -v '^[[:space:]]*$' | tail -n "${1:-40}" ;;
  kill) tmux kill-session -t "${name}" ;;
  *) usage ;;
esac
