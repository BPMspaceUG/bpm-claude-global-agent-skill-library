#!/usr/bin/env bats
# #158 — host inventory is written ONLY for the current host: write_host_inventory
# derives the host dir from $(hostname), never a hardcoded/other-host path.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
LIB="${REPO_ROOT}/lib.sh"

# Print just the body of write_host_inventory().
_wh_body() {
  awk '/^write_host_inventory\(\)/{f=1} f{print} f&&/^\}/{exit}' "$LIB"
}

@test "[#158] write_host_inventory derives the host dir from \$(hostname)" {
  local b; b="$(_wh_body)"
  echo "$b" | grep -qF 'host_name="$(hostname)"'
  echo "$b" | grep -qF 'my/hosts/$host_name'
}

@test "[#158] write_host_inventory writes no hardcoded host directory" {
  local b; b="$(_wh_body)"
  # no literal my/hosts/<name>/ target where <name> is a fixed hostname (not the $host_name variable)
  if echo "$b" | grep -qE 'my/hosts/[A-Za-z0-9._-]+/'; then
    echo "hardcoded host dir in write_host_inventory:" >&2
    echo "$b" | grep -nE 'my/hosts/[A-Za-z0-9._-]+/' >&2
    return 1
  fi
}

@test "[#158] guard bites: a hardcoded-host write path is caught" {
  local f; f="$(mktemp)"
  printf 'write_host_inventory() {\n  echo x > "$repo_dir/my/hosts/contabo03/skills.txt"\n}\n' > "$f"
  local b; b="$(awk '/^write_host_inventory\(\)/{f=1} f{print} f&&/^\}/{exit}' "$f")"
  rm -f "$f"
  echo "$b" | grep -qE 'my/hosts/[A-Za-z0-9._-]+/'   # the hardcoded path IS present -> guard would fire
}

@test "write_host_inventory survives an existing but empty category dir under set -euo pipefail" {
  local repo claude; repo="$(mktemp -d)"; claude="$(mktemp -d)"
  mkdir -p "${repo}/my" "${claude}/skills/c-bpm-sk-x" "${claude}/commands" "${claude}/agents"
  touch "${claude}/commands/c-bpm-cm-y.md"
  run bash -c 'set -euo pipefail; source "$1"; write_host_inventory "$2" "$3"; echo DONE' _ "${LIB}" "${repo}" "${claude}"
  local h; h="$(hostname)"
  [ "${status}" -eq 0 ] || { echo "${output}" >&2; rm -rf "${repo}" "${claude}"; return 1; }
  [[ "${output}" == *DONE* ]]
  grep -q '^c-bpm-sk-x$' "${repo}/my/hosts/${h}/skills.txt"
  grep -q '^# Category: agents' "${repo}/my/hosts/${h}/agents.txt"
  rm -rf "${repo}" "${claude}"
}

@test "write_host_inventory leaves a file untouched when only the timestamp would change" {
  local repo claude h; repo="$(mktemp -d)"; claude="$(mktemp -d)"; h="$(hostname)"
  mkdir -p "${repo}/my" "${claude}/skills/c-bpm-sk-x" "${claude}/commands" "${claude}/agents"
  bash -c 'set -euo pipefail; source "$1"; write_host_inventory "$2" "$3"' _ "${LIB}" "${repo}" "${claude}"
  local before; before="$(cat "${repo}/my/hosts/${h}/skills.txt")"
  sleep 1
  bash -c 'set -euo pipefail; source "$1"; write_host_inventory "$2" "$3"' _ "${LIB}" "${repo}" "${claude}"
  [ "$(cat "${repo}/my/hosts/${h}/skills.txt")" = "${before}" ]
  mkdir -p "${claude}/skills/c-bpm-sk-z"
  sleep 1
  bash -c 'set -euo pipefail; source "$1"; write_host_inventory "$2" "$3"' _ "${LIB}" "${repo}" "${claude}"
  grep -q '^c-bpm-sk-z$' "${repo}/my/hosts/${h}/skills.txt"
  [ "$(cat "${repo}/my/hosts/${h}/skills.txt")" != "${before}" ]
  rm -rf "${repo}" "${claude}"
}
