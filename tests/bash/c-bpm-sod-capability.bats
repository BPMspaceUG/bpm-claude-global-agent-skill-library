#!/usr/bin/env bats
# c-bpm-sod-capability.bats — regression guard for Issue #101.
#
# The SoD gate must be a CAPABILITY the teammate lacks, not a RULE it is asked to
# obey. Three things must hold, forever:
#   1. The PostToolUse hook must not order any agent to run the reviewer.
#   2. The teammate agent must not hold a shell.
#   3. The team command must have exactly one spawn path, and must never treat a
#      teammate's word as state.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  HOOK="${REPO_ROOT}/my/hooks/codex-sod-tracker.sh"
  AGENT="${REPO_ROOT}/my/agents/c-bpm-ag-teammate.md"
  CMD="${REPO_ROOT}/my/commands/c-bpm-cm-openissues-team.md"
  REFACTOR="${REPO_ROOT}/my/commands/c-bpm-cm-refactor-repo.md"
}

# The `tools:` line of the agent frontmatter, or empty if absent.
agent_tools_line() {
  awk '/^---$/{n++; next} n==1 && /^tools:/{print; exit}' "${AGENT}"
}

# --- 1. the hook must not issue the forbidden order -------------------------

@test "hook exists in the library (not only on one host)" {
  [ -f "${HOOK}" ]
  [ -x "${HOOK}" ]
}

@test "POST_EDIT context contains no instruction to run the reviewer" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/x/y.sh\"}}" | "$1" POST_EDIT' _ "${HOOK}"
  [ "$status" -eq 0 ]
  # This is the #101 regression: the hook told every agent, teammates included,
  # to run codex exec after every write.
  [[ "$output" != *"codex exec"* ]]
  [[ "$output" != *"MANDATORY"* ]]
  [[ "$output" != *"Run codex"* ]]
}

@test "POST_EDIT still emits valid JSON naming the changed file" {
  # Post-#168 the tracker is repo-confined: it names a file only when the file is
  # git-tracked inside the CURRENT session repo. Use a real in-repo tracked file
  # with cwd = the repo (an out-of-repo path like /x/y.sh now correctly yields {}).
  run bash -c 'printf "{\"tool_input\":{\"file_path\":\"%s/tests/run_tests.sh\"},\"cwd\":\"%s\",\"session_id\":\"sodcap3\"}" "$2" "$2" | "$1" POST_EDIT' _ "${HOOK}" "${REPO_ROOT}"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"'
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("run_tests.sh")'
  rm -rf /tmp/claude-codex-sod/sodcap3
}

@test "SessionStart rules do not order any agent to invoke the reviewer themselves" {
  run bash -c 'echo "{}" | "$1" SESSION_START' _ "${HOOK}"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"'
  ctx="$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')"
  # SessionStart is injected into EVERY agent session, teammates included. The old
  # rule 2 read "EVERY file change MUST be reviewed via: codex exec --skip-git-repo-check"
  # — a command, handed to the one party that must never run it.
  [[ "$ctx" != *"codex exec"* ]]
  [[ "$ctx" != *"--skip-git-repo-check"* ]]
}

@test "SessionStart names the Lead as sole invoker and teammate reports as non-state" {
  run bash -c 'echo "{}" | "$1" SESSION_START' _ "${HOOK}"
  ctx="$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')"
  [[ "$ctx" == *"TEAM LEAD ONLY"* ]]
  [[ "$ctx" == *"NARRATIVE, NEVER STATE"* ]]
}

@test "installed hook on this host matches the library copy (no local drift)" {
  # The imperative lived in ~/.claude/hooks; a library-only fix would leave it firing.
  if [ ! -f "${HOME}/.claude/hooks/codex-sod-tracker.sh" ]; then skip "hook not installed on this host"; fi
  run diff -q "${HOME}/.claude/hooks/codex-sod-tracker.sh" "${HOOK}"
  [ "$status" -eq 0 ]
}

# --- 2. the teammate must not hold a shell ----------------------------------

@test "c-bpm-ag-teammate agent definition exists with a tools: allowlist" {
  [ -f "${AGENT}" ]
  [ -n "$(agent_tools_line)" ]
}

@test "teammate tools: grants no Bash — codex exec, gh and git push are impossible" {
  line="$(agent_tools_line)"
  # Anchored on the tools: line only. Substring-matching the whole file is the
  # prose-vs-thing bug that produced three false-positive detectors (#97, #90).
  [[ "$line" != *"Bash"* ]]
  [[ "$line" != *"Task"* ]]
  [[ "$line" != *"Teammate"* ]]
}

@test "teammate tools: still grants what implementation actually needs" {
  line="$(agent_tools_line)"
  [[ "$line" == *"Read"* ]]
  [[ "$line" == *"Edit"* ]]
  [[ "$line" == *"Write"* ]]
}

# --- 3. one spawn path; teammate words are not state -------------------------

@test "every teammate-spawning command spawns the restricted agent in a worktree" {
  # Both commands, not just the one #101 was filed against: a single clean path is
  # worthless while a second capability path stays reachable.
  for c in "${CMD}" "${REFACTOR}"; do
    grep -q 'subagent_type: c-bpm-ag-teammate' "$c" || { echo "no restricted spawn in $c"; return 1; }
    grep -q 'isolation: "worktree"' "$c"            || { echo "no worktree isolation in $c"; return 1; }
  done
}

@test "every teammate-spawning command declares the Lead the sole gate of record" {
  for c in "${CMD}" "${REFACTOR}"; do
    grep -qi 'narrative, never state' "$c" || { echo "no gate-of-record clause in $c"; return 1; }
    grep -qi 'nonce' "$c"                  || { echo "no nonce requirement in $c"; return 1; }
  done
}

@test "no command keeps an unrestricted spawn path to fall back into" {
  # Rollback must be `git revert`, not "use the old path" (Codex plan-gate #3).
  for c in "${CMD}" "${REFACTOR}"; do
    n="$(grep -c 'subagent_type:' "$c")"
    [ "$n" -eq 1 ] || { echo "$c declares $n spawn paths, want exactly 1"; return 1; }
  done
}
