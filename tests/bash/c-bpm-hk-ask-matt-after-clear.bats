#!/usr/bin/env bats
#
# c-bpm-hk-ask-matt-after-clear.bats — Stop caches the last next-step line of
# an answer; SessionStart(clear) replays it at once, without a model run.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="${REPO_ROOT}/my/hooks/c-bpm-hk-ask-matt-after-clear.sh"
FRAGMENT="${REPO_ROOT}/my/hooks/c-bpm-hooks.json"

ROBERT='**Robert, du bist dran:** `/mattpocock-skills:triage` eintippen. ask-matt empfiehlt das, weil Test.'

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="${TEST_HOME}"
  mkdir -p "${HOME}/.claude/hooks" "${HOME}/proj"
  : >"${HOME}/proj/new.jsonl"
  export TMUX_PANE='%7'
  # tmux stub: records send-keys calls instead of typing into a real pane.
  mkdir -p "${HOME}/bin"
  printf '#!/bin/sh\nprintf "%%s|" "$@" >>"$HOME/tmux.calls"\n' >"${HOME}/bin/tmux"
  chmod +x "${HOME}/bin/tmux"
  export PATH="${HOME}/bin:${PATH}"
  export C_BPM_PREFILL_DELAY=0
}

wait_calls() { for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$HOME/tmux.calls" ] && return 0; sleep 0.2; done; return 1; }

teardown() { rm -rf "${TEST_HOME}"; }

stop_input() {
  jq -nc --arg m "$1" --arg h "$HOME" '{session_id:"old", cwd:$h, transcript_path:($h+"/proj/old.jsonl"), last_assistant_message:$m}'
}
clear_input() {
  printf '{"source":"%s","session_id":"new","transcript_path":"%s/proj/new.jsonl","cwd":"%s"}' "$1" "$HOME" "$HOME"
}

@test "save + clear: the last action line of the answer is replayed" {
  msg="$(printf 'Some answer.\n\n**Robert, du bist dran:** alt.\n\nMore.\n\n%s' "$ROBERT")"
  stop_input "$msg" | "$HOOK" save
  run bash -c "$(declare -f clear_input); clear_input clear | '$HOOK' clear"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg r "$ROBERT" '.systemMessage == ("Letzter Hinweis vor /clear: " + $r)'
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("mattpocock-skills:triage")'
}

@test "save: the Claude-acts form is cached too" {
  stop_input '**Claude ist dran, du musst nichts tun:** Watchdog prüft.' | "$HOOK" save
  grep -q 'Claude ist dran' "$HOME/.cache/c-bpm-next-step/pane-7"
}

@test "save: an answer without action line keeps the previous cache" {
  stop_input "$ROBERT" | "$HOOK" save
  stop_input 'no line here' | "$HOOK" save
  grep -qF "$ROBERT" "$HOME/.cache/c-bpm-next-step/pane-7"
}

@test "clear outside tmux: falls back to the directory cache" {
  stop_input "$ROBERT" | "$HOOK" save
  unset TMUX_PANE
  run bash -c "$(declare -f clear_input); clear_input clear | '$HOOK' clear"
  echo "$output" | jq -e '.systemMessage | contains("mattpocock-skills:triage")'
}

@test "clear without cache: scans the cleared transcript" {
  jq -nc --arg t "$ROBERT" '{type:"assistant", message:{content:[{type:"text", text:$t}]}}' >"$HOME/proj/old.jsonl"
  run bash -c "$(declare -f clear_input); clear_input clear | '$HOOK' clear"
  echo "$output" | jq -e '.systemMessage | contains("mattpocock-skills:triage")'
}

@test "clear with nothing found: exit 0 and a notice" {
  run bash -c "$(declare -f clear_input); clear_input clear | '$HOOK' clear"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage | contains("kein gespeicherter Hinweis")'
}

@test "startup and resume: no output" {
  run bash -c "$(declare -f clear_input); clear_input startup | '$HOOK' clear"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "fragment wires clear to SessionStart and save to Stop" {
  jq -e '.SessionStart[] | select(.matcher == "clear") | .hooks[] | select(.command | endswith("c-bpm-hk-ask-matt-after-clear.sh clear"))' "$FRAGMENT"
  jq -e '.Stop[] | .hooks[] | select(.command | endswith("c-bpm-hk-ask-matt-after-clear.sh save"))' "$FRAGMENT"
}

@test "clear in tmux: the slash command is typed into the prompt, without Enter" {
  stop_input "$ROBERT" | "$HOOK" save
  clear_input clear | "$HOOK" clear >/dev/null
  wait_calls
  [ "$(cat "$HOME/tmux.calls")" = "send-keys|-t|%7|-l|/mattpocock-skills:triage|" ]
}

@test "clear: no prefill for the Claude-acts form or a line without /command" {
  stop_input '**Claude ist dran, du musst nichts tun:** `/c-bpm-sk-gogo` läuft.' | "$HOOK" save
  clear_input clear | "$HOOK" clear >/dev/null
  stop_input '**Robert, du bist dran:** Q1 beantworten.' | "$HOOK" save
  clear_input clear | "$HOOK" clear >/dev/null
  sleep 1
  [ ! -e "$HOME/tmux.calls" ]
}

@test "clear outside tmux: no prefill" {
  stop_input "$ROBERT" | "$HOOK" save
  unset TMUX_PANE
  clear_input clear | "$HOOK" clear >/dev/null
  sleep 1
  [ ! -e "$HOME/tmux.calls" ]
}

@test "clear writes the status-line hint for the new session; the first answer removes it" {
  stop_input "$ROBERT" | "$HOOK" save
  clear_input clear | "$HOOK" clear >/dev/null
  grep -qF "$ROBERT" "$HOME/.cache/c-bpm-next-step/session-new"
  jq -nc '{session_id:"new", last_assistant_message:"x"}' | "$HOOK" save
  [ ! -e "$HOME/.cache/c-bpm-next-step/session-new" ]
}
