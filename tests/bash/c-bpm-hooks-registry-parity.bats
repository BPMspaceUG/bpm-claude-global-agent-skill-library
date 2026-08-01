#!/usr/bin/env bats
#
# c-bpm-hooks-registry-parity.bats — full-inventory rule for my/hooks/ (#151).
#
# Every TOP-LEVEL FILE in my/hooks/ (any extension; the __tests__/ directory
# is excluded — fixtures live there) must be exactly one of:
#   1. a registry-managed pair: its basename (sans extension) has a
#      HOOK_REGISTRY row in ./install-hooks, with BOTH my/hooks/<name>.ts and
#      dist/<name>.mjs present; or
#   2. an explicit allowlist entry below, each with its anchor.
# Anything else — a stray .mjs, .sh, .py, or unregistered .ts — fails,
# naming the file. This is the mechanical form of #151's acceptance:
# my/hooks/ holds only registered-or-tracked sources.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

# Non-registry hook files that are legitimate, with their anchors:
# - codex-sod-tracker.sh: SessionStart/PostToolUse/Stop hook installed via
#   settings.json (not the PreToolUse registry); exercised and parity-pinned
#   by tests/bash/c-bpm-sod-capability.bats (tests 1-6).
ALLOWLIST=(
  "codex-sod-tracker.sh"
)

registry_names() {
  sed -n '/^HOOK_REGISTRY=(/,/^)/p' "${REPO_ROOT}/install-hooks" \
    | grep -oE '"[^"|]+\|' | tr -d '"|'
}

in_list() { # <needle> <items...>
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "${x}" == "${needle}" ]] && return 0; done
  return 1
}

@test "#151: every top-level my/hooks/ file is registry-managed or allowlisted" {
  local bad=0 f base stem
  local -a reg=()
  while IFS= read -r n; do reg+=("${n}"); done < <(registry_names)
  [ "${#reg[@]}" -gt 0 ] || { echo "could not parse HOOK_REGISTRY"; return 1; }
  for f in "${REPO_ROOT}"/my/hooks/*; do
    [[ -f "${f}" ]] || continue   # rule covers top-level FILES, not directories
    base="$(basename "${f}")"
    stem="${base%.*}"
    if in_list "${base}" "${ALLOWLIST[@]}"; then continue; fi
    if in_list "${stem}" "${reg[@]}" && [[ "${base}" == "${stem}.ts" ]]; then continue; fi
    echo "unmanaged file in my/hooks/: ${base} (no HOOK_REGISTRY row for a .ts source, not allowlisted)"
    bad=1
  done
  return "${bad}"
}

@test "#151: every HOOK_REGISTRY row has both its ts source and dist artifact" {
  local bad=0 n
  while IFS= read -r n; do
    [[ -f "${REPO_ROOT}/my/hooks/${n}.ts" ]]  || { echo "registry row ${n}: missing my/hooks/${n}.ts"; bad=1; }
    [[ -f "${REPO_ROOT}/dist/${n}.mjs" ]]     || { echo "registry row ${n}: missing dist/${n}.mjs"; bad=1; }
  done < <(registry_names)
  return "${bad}"
}

@test "#151: every dist/*.mjs has a HOOK_REGISTRY row" {
  local bad=0 f stem
  local -a reg=()
  while IFS= read -r n; do reg+=("${n}"); done < <(registry_names)
  for f in "${REPO_ROOT}"/dist/*.mjs; do
    [[ -f "${f}" ]] || continue
    stem="$(basename "${f}" .mjs)"
    in_list "${stem}" "${reg[@]}" || { echo "dist artifact without registry row: $(basename "${f}")"; bad=1; }
  done
  return "${bad}"
}
