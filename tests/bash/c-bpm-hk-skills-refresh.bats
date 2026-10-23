#!/usr/bin/env bats
#
# c-bpm-hk-skills-refresh.bats — the skills refresh hook and the shared Pocock
# update/unlock logic behind /c-bpm-cm-pocock-update.
#
# Decision (Codex, 2026-10-23): a SessionStart hook (startup|resume) unlocks the
# installed Pocock skills locally and synchronously, then starts a detached
# worker — at most once per 24 h, failures included — that runs the plugin
# update, unlocks again and runs c-bpm-cm-library-pull. Changes take effect in
# the next session. spec-oneshot Step 0 only verifies the current session.
#
# External commands are replaced by fakes via C_BPM_CLAUDE_BIN and
# C_BPM_PULL_BIN; the upstream manifest via POCOCK_MANIFEST_URL.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/my/hooks/c-bpm-hk-skills-refresh.sh"
FRAGMENT="${REPO_ROOT}/my/hooks/c-bpm-hooks.json"

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="${TEST_HOME}"
  export POCOCK_MANIFEST_URL="file://${HOME}/manifest.json"
  export C_BPM_CLAUDE_BIN="${HOME}/bin/fake-claude"
  export C_BPM_PULL_BIN="${HOME}/bin/fake-pull"
  mkdir -p "${HOME}/bin" "${HOME}/.claude/hooks"
  printf '#!/bin/sh\necho "claude $*" >> "$HOME/calls"\nexit ${FAKE_CLAUDE_RC:-0}\n' > "${C_BPM_CLAUDE_BIN}"
  printf '#!/bin/sh\necho "pull $*" >> "$HOME/calls"\n' > "${C_BPM_PULL_BIN}"
  chmod +x "${C_BPM_CLAUDE_BIN}" "${C_BPM_PULL_BIN}"
  printf '{"version":"9.9.9"}' > "${HOME}/manifest.json"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

fake_plugin() { # <locked-count>
  local base="${HOME}/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9/skills" i
  for i in 1 2 3; do
    mkdir -p "${base}/s${i}"
    if [ "${i}" -le "$1" ]; then
      printf -- '---\nname: s%s\ndisable-model-invocation: true\ndescription: d\n---\nbody mentions disable-model-invocation: true\n' "${i}"
    else
      printf -- '---\nname: s%s\ndescription: d\n---\nbody\n' "${i}"
    fi > "${base}/s${i}/SKILL.md"
  done
  printf '{"version":2,"plugins":{"mattpocock-skills@mattpocock":[{"version":"9.9.9","installPath":"%s/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9"}]}}' "${HOME}" \
    > "${HOME}/.claude/plugins/installed_plugins.json"
}

locked() {
  { grep -rlE '^disable-model-invocation:[[:space:]]*true' "${HOME}/.claude/plugins/cache" 2>/dev/null || true; } | wc -l
}

wait_for_calls() { # <expected-line-count>
  local i
  for i in $(seq 1 50); do
    [ "$( (cat "${HOME}/calls" 2>/dev/null || true) | wc -l)" -ge "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

# ------------------------------------------------------------------
# shared logic: check / unlock / update
# ------------------------------------------------------------------

@test "script exists, is executable and parses" {
  [ -x "${SCRIPT}" ]
  bash -n "${SCRIPT}"
}

@test "unlock: strips the lock from frontmatter only, leaves the body, idempotent" {
  fake_plugin 2
  run "${SCRIPT}" unlock
  [ "${status}" -eq 0 ] || { echo "${output}" >&2; return 1; }
  [[ "${output}" == *"| unlocked this run | 2 |"* ]]
  [[ "${output}" == *"| still locked | 0 |"* ]]
  [ "$(locked)" -eq 0 ]
  grep -q 'body mentions disable-model-invocation: true' "${HOME}/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9/skills/s1/SKILL.md"
  run "${SCRIPT}" unlock
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"| unlocked this run | 0 |"* ]]
}

@test "unlock: makes no network call and never runs claude" {
  fake_plugin 1
  rm -f "${HOME}/manifest.json"
  run "${SCRIPT}" unlock
  [ "${status}" -eq 0 ]
  [ ! -e "${HOME}/calls" ]
}

@test "check: reports versions and locked count, exits 0 with nothing locked (pipefail regression)" {
  fake_plugin 0
  run "${SCRIPT}" check
  [ "${status}" -eq 0 ] || { echo "${output}" >&2; return 1; }
  [[ "${output}" == *"| installed version | 9.9.9 |"* ]]
  [[ "${output}" == *"| upstream version | 9.9.9 |"* ]]
  [[ "${output}" == *"| locked skills | 0 |"* ]]
}

@test "update: runs the plugin update non-interactively, then unlocks" {
  fake_plugin 3
  run "${SCRIPT}" update
  [ "${status}" -eq 0 ] || { echo "${output}" >&2; return 1; }
  grep -q '^claude plugin update -y mattpocock-skills@mattpocock$' "${HOME}/calls"
  [[ "${output}" == *"| plugin update | ok |"* ]]
  [ "$(locked)" -eq 0 ]
}

@test "update: a failing plugin update still unlocks and reports the failure" {
  fake_plugin 2
  FAKE_CLAUDE_RC=1 run "${SCRIPT}" update
  [[ "${output}" == *"| plugin update | failed"* ]]
  [ "$(locked)" -eq 0 ]
}

@test "never touches the marketplace clone" {
  ! grep -q 'plugins/marketplaces' "${SCRIPT}"
}

@test "missing plugin: unlock and check fail with an install hint, hook mode still exits 0" {
  run "${SCRIPT}" unlock
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"claude plugin install mattpocock-skills@mattpocock"* ]]
  run bash -c 'printf "{}" | "$1" hook' _ "${SCRIPT}"
  [ "${status}" -eq 0 ]
}

# ------------------------------------------------------------------
# hook mode (SessionStart)
# ------------------------------------------------------------------

@test "hook: unlocks synchronously, prints nothing, returns fast" {
  fake_plugin 2
  local t0 t1
  t0="$(date +%s)"
  run bash -c 'printf "{\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$1" hook' _ "${SCRIPT}"
  t1="$(date +%s)"
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
  [ "$(locked)" -eq 0 ]
  [ $((t1 - t0)) -lt 5 ]
}

@test "hook: first run starts the detached worker: plugin update, then library pull" {
  fake_plugin 0
  run bash -c 'printf "{}" | "$1" hook' _ "${SCRIPT}"
  [ "${status}" -eq 0 ]
  wait_for_calls 2
  [ "$(sed -n 1p "${HOME}/calls")" = "claude plugin update -y mattpocock-skills@mattpocock" ]
  [ "$(sed -n 2p "${HOME}/calls")" = "pull " ]
}

@test "hook: throttled — a second start within 24 h spawns no worker" {
  fake_plugin 0
  run bash -c 'printf "{}" | "$1" hook' _ "${SCRIPT}"
  wait_for_calls 2
  run bash -c 'printf "{}" | "$1" hook' _ "${SCRIPT}"
  sleep 1
  [ "$(wc -l < "${HOME}/calls")" -eq 2 ]
}

@test "hook: an old stamp (older than the interval) runs the worker again" {
  fake_plugin 0
  mkdir -p "${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.d"
  echo $(( $(date +%s) - 90000 )) > "${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.d/last-attempt"
  run bash -c 'printf "{}" | "$1" hook' _ "${SCRIPT}"
  wait_for_calls 2
}

@test "worker: the library pull still runs when the plugin update fails" {
  fake_plugin 1
  FAKE_CLAUDE_RC=1 run "${SCRIPT}" worker
  [ "${status}" -eq 0 ]
  grep -q '^pull' "${HOME}/calls"
  [ "$(locked)" -eq 0 ]
  grep -q 'plugin update | failed' "${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.log"
}

@test "worker: a held lock makes a second worker exit without doing anything" {
  command -v flock >/dev/null || skip "flock not available"
  fake_plugin 0
  mkdir -p "${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.d"
  exec 9>"${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.d/lock"
  flock -n 9
  run "${SCRIPT}" worker
  exec 9>&-
  [ "${status}" -eq 0 ]
  [ ! -e "${HOME}/calls" ]
}

@test "log is capped" {
  fake_plugin 0
  head -c 300000 /dev/zero | tr '\0' 'x' > "${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.log"
  run "${SCRIPT}" worker
  [ "$(wc -c < "${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.log")" -lt 262144 ]
}

# ------------------------------------------------------------------
# wiring
# ------------------------------------------------------------------

@test "fragment: refresh hook on SessionStart startup|resume, cleanup sweep stays startup|clear" {
  [ "$(jq -r '.SessionStart[] | select(.hooks[0].command | contains("c-bpm-hk-skills-refresh.sh")) | .matcher' "${FRAGMENT}")" = "startup|resume" ]
  [ "$(jq -r '.SessionStart[] | select(.hooks[0].command | contains("c-bpm-hk-skills-refresh.sh")) | .hooks[0].command' "${FRAGMENT}")" = "~/.claude/hooks/c-bpm-hk-skills-refresh.sh hook" ]
  [ "$(jq -r '.SessionStart[] | select(.hooks[0].command | contains("c-bpm-hk-agent-cleanup-guard.sh")) | .matcher' "${FRAGMENT}")" = "startup|clear" ]
}

@test "the pocock-update command delegates to the script instead of carrying its own copy" {
  local cmd="${REPO_ROOT}/my/commands/c-bpm-cm-pocock-update.md"
  grep -qF '~/.claude/hooks/c-bpm-hk-skills-refresh.sh' "${cmd}"
  ! grep -q 'disable-model-invocation:\[\[:space:\]\]' "${cmd}"
}

@test "spec-oneshot Step 0 verifies model-callable Pocock skills and never runs the refresh itself" {
  local spec="${REPO_ROOT}/my/commands/c-bpm-cm-spec-oneshot.md"
  local step0; step0="$(awk '/^## Step 0 /{f=1;next} /^## Step 1 /{f=0} f' "${spec}")"
  [[ "${step0}" == *"model-callable"* ]]
  [[ "${step0}" == *"c-bpm-hk-skills-refresh.sh check"* ]]
  [[ "${step0}" != *"c-bpm-cm-library-pull"* ]] || [[ "${step0}" == *"never runs"* ]]
}
