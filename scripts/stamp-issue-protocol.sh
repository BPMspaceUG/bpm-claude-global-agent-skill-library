#!/usr/bin/env bash
# stamp-issue-protocol.sh — stamp the canonical "Communication: GitHub Issues only"
# block (my/shared/issue-communication-protocol.md) into every c-bpm skill and
# command. Single source of truth -> stamped into all -> zero drift (Issue #104).
# Idempotent: re-running produces byte-identical files. Enforced by
# tests/bash/issue-comms-anchor.bats.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASTER="${ROOT}/my/shared/issue-communication-protocol.md"
[[ -f "${MASTER}" ]] || { echo "ERROR: master not found: ${MASTER}" >&2; exit 1; }
BLOCK="$(cat "${MASTER}")"

shopt -s nullglob
targets=( "${ROOT}"/my/skills/c-bpm-sk-*/SKILL.md "${ROOT}"/my/commands/c-bpm-cm-*.md )
(( ${#targets[@]} > 0 )) || { echo "ERROR: no target skills/commands found" >&2; exit 1; }

n=0
for f in "${targets[@]}"; do
  tmp="$(mktemp "${f}.stampXXXXXX")"
  # Drop any existing block (BEGIN..END inclusive), then drop trailing blank lines.
  awk '
    /<!-- BEGIN issue-comms/ { skip=1 }
    skip!=1 { print }
    /<!-- END issue-comms/   { skip=0 }
  ' "${f}" | awk '
    { lines[NR]=$0 }
    END { last=NR; while (last>0 && lines[last] ~ /^[[:space:]]*$/) last--; for(i=1;i<=last;i++) print lines[i] }
  ' > "${tmp}"
  # Re-append the canonical block, separated by exactly one blank line.
  printf '\n%s\n' "${BLOCK}" >> "${tmp}"
  mv "${tmp}" "${f}"
  n=$((n + 1))
done

echo "stamped issue-comms block into ${n} files"
