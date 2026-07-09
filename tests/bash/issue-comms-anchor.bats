#!/usr/bin/env bats
# issue-comms-anchor.bats — CI drift-guard for Issue #104.
# Every c-bpm skill and command MUST carry the canonical "Communication: GitHub
# Issues only" block, byte-identical to the master. Fails on absence or drift.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  MASTER="${REPO_ROOT}/my/shared/issue-communication-protocol.md"
}

# Extract the BEGIN..END block (inclusive) from a file.
extract_block() {
  awk '
    /<!-- BEGIN issue-comms/ { p=1 }
    p { print }
    /<!-- END issue-comms/   { p=0 }
  ' "$1"
}

@test "master issue-communication-protocol.md exists" {
  [ -f "${MASTER}" ]
}

@test "every c-bpm skill + command carries the canonical block, byte-identical to master" {
  local master_block bad=0
  master_block="$(extract_block "${MASTER}")"
  [ -n "${master_block}" ]

  shopt -s nullglob
  local targets=( "${REPO_ROOT}"/my/skills/c-bpm-sk-*/SKILL.md "${REPO_ROOT}"/my/commands/c-bpm-cm-*.md )
  [ "${#targets[@]}" -gt 0 ]

  for f in "${targets[@]}"; do
    local block
    block="$(extract_block "${f}")"
    if [ "${block}" != "${master_block}" ]; then
      printf 'DRIFT/MISSING issue-comms block in: %s\n' "${f#${REPO_ROOT}/}" >&2
      bad=1
    fi
  done
  [ "${bad}" -eq 0 ]
}
