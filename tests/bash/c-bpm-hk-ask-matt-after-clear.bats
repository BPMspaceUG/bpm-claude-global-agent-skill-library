#!/usr/bin/env bats
#
# c-bpm-hk-ask-matt-after-clear.bats — the SessionStart(clear) hook asks a
# headless claude run (stubbed here) for Robert's next step and shows it.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="${REPO_ROOT}/my/hooks/c-bpm-hk-ask-matt-after-clear.sh"
FRAGMENT="${REPO_ROOT}/my/hooks/c-bpm-hooks.json"

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="${TEST_HOME}"
  mkdir -p "${HOME}/.claude/hooks" "${HOME}/ask" "${HOME}/proj" "${HOME}/bin"
  printf 'ASK-MATT ROUTER TEXT\n' >"${HOME}/ask/SKILL.md"
  export C_BPM_ASK_MATT_DIR="${HOME}/ask"
  printf '%s\n' '{"type":"user","message":{"content":"PREVIOUS-CONVERSATION-MARKER"}}' >"${HOME}/proj/old.jsonl"
  : >"${HOME}/proj/new.jsonl"
  cat >"${HOME}/bin/claude" <<'STUB'
#!/usr/bin/env bash
cat >"$HOME/prompt.txt"
echo "**Robert, du bist dran:** \`/mattpocock-skills:triage\` eintippen. ask-matt empfiehlt das, weil Test."
STUB
  chmod +x "${HOME}/bin/claude"
  export C_BPM_ASK_MATT_CLAUDE="${HOME}/bin/claude"
  unset C_BPM_ASK_MATT_CHILD
}

teardown() { rm -rf "${TEST_HOME}"; }

input() { printf '{"source":"%s","session_id":"new","transcript_path":"%s/proj/new.jsonl","cwd":"%s"}' "$1" "$HOME" "$HOME"; }

@test "clear: shows ask-matt's line to Robert and to the new session" {
  run bash -c "$(declare -f input); input clear | '$HOOK'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage | startswith("ask-matt nach /clear: **Robert, du bist dran:**")'
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("mattpocock-skills:triage")'
}

@test "clear: the prompt carries the router and the cleared conversation" {
  bash -c "$(declare -f input); input clear | '$HOOK'" >/dev/null
  grep -q 'ASK-MATT ROUTER TEXT' "$HOME/prompt.txt"
  grep -q 'PREVIOUS-CONVERSATION-MARKER' "$HOME/prompt.txt"
}

@test "startup and resume: no output" {
  run bash -c "$(declare -f input); input startup | '$HOOK'"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "child run never recurses" {
  run bash -c "$(declare -f input); input clear | C_BPM_ASK_MATT_CHILD=1 '$HOOK'"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "failing headless run: exit 0 and an error message" {
  printf '#!/usr/bin/env bash\nexit 3\n' >"$HOME/bin/claude"
  run bash -c "$(declare -f input); input clear | '$HOOK'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage | contains("fehlgeschlagen")'
}

@test "fragment wires the hook to SessionStart clear" {
  jq -e '.SessionStart[] | select(.matcher == "clear") | .hooks[] | select(.command | contains("c-bpm-hk-ask-matt-after-clear.sh"))' "$FRAGMENT"
}
