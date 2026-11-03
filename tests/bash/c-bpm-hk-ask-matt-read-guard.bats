#!/usr/bin/env bats
#
# c-bpm-hk-ask-matt-read-guard.bats — Stop sends an answer back once when its
# next-step line cites ask-matt but ask-matt was not read in the session.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
GUARD="${REPO_ROOT}/my/hooks/c-bpm-hk-ask-matt-read-guard.sh"
FRAGMENT="${REPO_ROOT}/my/hooks/c-bpm-hooks.json"
LINE='**Robert, du bist dran:** `/mattpocock-skills:retro` eintippen. ask-matt empfiehlt das, weil Test.'

setup() { T="$(mktemp -d)"; : >"$T/t.jsonl"; }
teardown() { rm -rf "$T"; }

tool_use() { jq -nc --argjson i "$1" '{type:"assistant", message:{content:[{type:"tool_use", name:"X", input:$i}]}}' >>"$T/t.jsonl"; }
say() { jq -nc --arg r "$1" --arg t "$2" '{type:$r, message:{content:[{type:"text", text:$t}]}}' >>"$T/t.jsonl"; }
stop() { jq -nc --arg m "$1" --arg t "$T/t.jsonl" --argjson a "${2:-false}" '{last_assistant_message:$m, transcript_path:$t, stop_hook_active:$a}' | "$GUARD"; }

@test "ask-matt cited, never read: blocked with the path to read" {
  run stop "$LINE"
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *ask-matt/SKILL.md* ]]
}

@test "the next-step skill naming the path in text does not count as a read" {
  say user 'Before writing the line, read `~/.claude/plugins/marketplaces/mattpocock/skills/engineering/ask-matt/SKILL.md`'
  say assistant 'I will read ask-matt/SKILL.md later.'
  run stop "$LINE"
  [ "$(jq -r .decision <<<"$output")" = block ]
}

@test "read via Read or Bash: allowed" {
  tool_use '{"file_path":"/home/x/.claude/plugins/marketplaces/mattpocock/skills/engineering/ask-matt/SKILL.md"}'
  run stop "$LINE"
  [ -z "$output" ]
  : >"$T/t.jsonl"
  tool_use '{"command":"sed -n 1,80p ~/.claude/plugins/marketplaces/mattpocock/skills/engineering/ask-matt/SKILL.md | head"}'
  run stop "$LINE"
  [ -z "$output" ]
}

@test "Skill call or Robert invoking /ask-matt: allowed" {
  tool_use '{"skill":"mattpocock-skills:ask-matt"}'
  run stop "$LINE"
  [ -z "$output" ]
  : >"$T/t.jsonl"
  say user $'Base directory for this skill: /home/x/.claude/plugins/cache/mattpocock/mattpocock-skills/1.3.2/skills/engineering/ask-matt\n\n# Ask Matt'
  run stop "$LINE"
  [ -z "$output" ]
}

@test "no ask-matt citation, or the retry after a block: no output" {
  run stop '**Claude ist dran, du musst nichts tun:** warten. Nächster Check um 10:00.'
  [ -z "$output" ]
  run stop "$LINE" true
  [ -z "$output" ]
}

@test "fragment wires the guard to Stop" {
  jq -e '[.Stop[].hooks[].command] | any(contains("c-bpm-hk-ask-matt-read-guard.sh"))' "$FRAGMENT"
}
