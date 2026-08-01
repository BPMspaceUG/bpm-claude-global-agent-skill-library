#!/usr/bin/env bats
#
# c-bpm-sk-findings-to-issues.bats — guards for the Findings → Issues rule
# (Issue #62: every finding-surfacing skill files each finding as an Issue
# immediately, never asks; contradiction classes purged, incl. references/).
#
# SKILL.md assertions run on the authored region (stamped issue-comms block
# stripped; byte identity owned by issue-comms-anchor.bats). Absence checks
# additionally run RECURSIVELY over each skill's references/ directory.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

# The twelve finding-surfacing skills named by #62. Cardinality is pinned:
# silent shrinkage of this list must fail, not pass.
FINDING_SKILLS=(
  c-bpm-sk-auditor
  c-bpm-sk-grill-me
  c-bpm-sk-grill-me-issue
  c-bpm-sk-grill-claude-issue
  c-bpm-sk-library-manager
  c-bpm-sk-skill-creator
  c-bpm-sk-skill-optimizer
  c-bpm-sk-linux-audit
  c-bpm-sk-php-crud-api-review
  c-bpm-sk-appsec-threatlite
  c-bpm-sk-question-auditor
  c-bpm-sk-idea-merge
)

authored() { # <file>
  awk '
    /<!-- BEGIN issue-comms/ { p=1 }
    !p { print }
    /<!-- END issue-comms/   { p=0 }
  ' "$1"
}

# All instruction text of a skill: authored SKILL.md + every references/ file.
skill_text() { # <skill-name>
  local dir="${REPO_ROOT}/my/skills/$1"
  authored "${dir}/SKILL.md"
  if [[ -d "${dir}/references" ]]; then
    find "${dir}/references" -type f -exec cat {} +
  fi
}

@test "#62: exactly 12 finding-surfacing skills, all present on disk" {
  [ "${#FINDING_SKILLS[@]}" -eq 12 ]
  local s bad=0
  for s in "${FINDING_SKILLS[@]}"; do
    [ -f "${REPO_ROOT}/my/skills/${s}/SKILL.md" ] || { echo "missing ${s}"; bad=1; }
  done
  return "${bad}"
}

@test "#62: every skill carries the Findings → Issues section with the four positive markers" {
  local s body bad=0
  for s in "${FINDING_SKILLS[@]}"; do
    body="$(authored "${REPO_ROOT}/my/skills/${s}/SKILL.md")"
    echo "${body}" | grep -qF 'Findings → Issues'         || { echo "${s}: section heading missing"; bad=1; }
    echo "${body}" | grep -qiF 'immediately'              || { echo "${s}: 'immediately' missing"; bad=1; }
    echo "${body}" | grep -qiE 'never ask'                || { echo "${s}: never-ask rule missing"; bad=1; }
    echo "${body}" | grep -qF 'milestone `new`'           || { echo "${s}: milestone rule missing"; bad=1; }
    echo "${body}" | grep -qiE 'exactly one.*(`bug`|`enhancement`)' || { echo "${s}: one-type-label rule missing"; bad=1; }
  done
  return "${bad}"
}

@test "#62: no contradiction class survives in any skill text (SKILL.md + references/, recursive)" {
  local s text bad=0 hits
  for s in "${FINDING_SKILLS[@]}"; do
    text="$(skill_text "${s}")"
    hits="$(echo "${text}" | grep -niE 'report only|no (github )?issues (are )?created|ask the user (whether|if)|without asking the user|asking the user first|should (i|the issue griller) (file|assign|create|take)|no labels|no tags|\[BUG\]|\[ENHANCEMENT\]|per-session limit|[0-9]-per-session|issues per session' || true)"
    if [ -n "${hits}" ]; then
      printf '%s still carries contradiction wording:\n%s\n' "${s}" "${hits}" >&2
      bad=1
    fi
  done
  return "${bad}"
}

@test "#62: both team-orchestration references carry the canonical one-type-label rule" {
  local f bad=0
  for f in \
    "${REPO_ROOT}/my/skills/c-bpm-sk-skill-optimizer/references/team-orchestration.md" \
    "${REPO_ROOT}/my/skills/c-bpm-sk-flightphp-pro/references/team-orchestration.md"
  do
    grep -qiE 'exactly one.*(`bug`|`enhancement`)|one (lowercase )?type label' "${f}" || { echo "canonical label rule missing in ${f}"; bad=1; }
    grep -qiE 'no labels|no tags' "${f}" && { echo "no-labels wording still in ${f}"; bad=1; }
  done
  return "${bad}"
}

@test "#62: idea-merge keeps destructive-action approval while filing never asks" {
  local body
  body="$(authored "${REPO_ROOT}/my/skills/c-bpm-sk-idea-merge/SKILL.md")"
  echo "${body}" | grep -qiE 'approv.*(cluster|merge|destructive)'
  echo "${body}" | grep -qiE 'never ask'
}

@test "#62: CLAUDE.md cross-references the rule and this guard suite" {
  grep -qF 'c-bpm-sk-findings-to-issues.bats' "${REPO_ROOT}/CLAUDE.md"
}
