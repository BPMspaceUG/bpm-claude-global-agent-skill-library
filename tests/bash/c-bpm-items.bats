#!/usr/bin/env bats
#
# c-bpm-items.bats — content guards for the custom items under my/
# Run with: bats tests/bash/c-bpm-items.bats
#
# Static, offline. Guards the shape every item must keep so that the sync
# scripts install it under the right name and the overnight flows can rely on
# the structure the README promises.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SPEC_CMD="${REPO_ROOT}/my/commands/c-bpm-cm-spec-oneshot.md"
GOGO_DIR="${REPO_ROOT}/my/skills/c-bpm-sk-gogo"

# Frontmatter body (between the first two '---' lines).
frontmatter() {
  awk 'NR==1 && $0!="---" {exit 1} NR>1 && $0=="---" {exit} NR>1' "$1"
}

# ------------------------------------------------------------------
# shape of every item
# ------------------------------------------------------------------

@test "every command file carries a frontmatter name equal to its file name" {
  local bad=0 f name fm_name
  for f in "${REPO_ROOT}"/my/commands/c-bpm-cm-*.md; do
    name="$(basename "${f}" .md)"
    fm_name="$(frontmatter "${f}" | awk -F': *' '$1=="name"{print $2; exit}')"
    [ "${fm_name}" = "${name}" ] || { printf '%s: frontmatter name is "%s"\n' "${name}" "${fm_name}" >&2; bad=1; }
  done
  return "${bad}"
}

@test "every skill directory carries a SKILL.md whose frontmatter name equals the directory name" {
  local bad=0 d name fm_name
  for d in "${REPO_ROOT}"/my/skills/c-bpm-sk-*/; do
    name="$(basename "${d}")"
    [ -f "${d}/SKILL.md" ] || { printf '%s: SKILL.md missing\n' "${name}" >&2; bad=1; continue; }
    fm_name="$(frontmatter "${d}/SKILL.md" | awk -F': *' '$1=="name"{print $2; exit}')"
    [ "${fm_name}" = "${name}" ] || { printf '%s: frontmatter name is "%s"\n' "${name}" "${fm_name}" >&2; bad=1; }
  done
  return "${bad}"
}

@test "every item has a non-empty description" {
  local bad=0 f
  for f in "${REPO_ROOT}"/my/commands/c-bpm-cm-*.md "${REPO_ROOT}"/my/skills/c-bpm-sk-*/SKILL.md; do
    frontmatter "${f}" | grep -qE '^description: *"?[^" ]' || { printf '%s: description missing\n' "${f#"${REPO_ROOT}"/}" >&2; bad=1; }
  done
  return "${bad}"
}

@test "no item pins a model name or version (#98)" {
  local hits
  hits="$(grep -rnEi -- '(gpt-[0-9]|opus[- ][0-9]|sonnet[- ][0-9]|haiku[- ][0-9]|claude-[0-9]|gemini[- ][0-9]|-m gpt)' "${REPO_ROOT}/my/" || true)"
  if [ -n "${hits}" ]; then
    printf 'model pin found under my/:\n%s\n' "${hits}" >&2
    return 1
  fi
}

@test "no item references removed hooks, agents or skills" {
  local hits
  hits="$(grep -rnE -- 'install-hooks|issue-write-gate|plan-doc-gate|codex-sod-tracker|c-bpm-sk-devils-advocate|c-bpm-sk-llm-selection|c-bpm-ag-teammate|c-bpm-cm-openissues' "${REPO_ROOT}/my/commands" "${REPO_ROOT}/my/skills" || true)"
  if [ -n "${hits}" ]; then
    printf 'reference to removed machinery:\n%s\n' "${hits}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# c-bpm-cm-spec-oneshot
# ------------------------------------------------------------------

@test "spec-oneshot: all eight steps are present in order" {
  local prev=-1 n
  for n in 0 1 2 3 4 5 6 7; do
    local line
    line="$(grep -nE "^## Step ${n} " "${SPEC_CMD}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ] || { printf 'Step %s heading missing\n' "${n}" >&2; return 1; }
    [ "${line}" -gt "${prev}" ] || { printf 'Step %s is out of order\n' "${n}" >&2; return 1; }
    prev="${line}"
  done
}

@test "spec-oneshot: the spec skeleton has exactly 18 numbered sections ending with References" {
  local count last
  count="$(awk '/^## Step 3 /{f=1;next} /^## Step 4 /{f=0} f && /^[0-9]+\. \*\*/' "${SPEC_CMD}" | wc -l)"
  [ "${count}" -eq 18 ] || { printf 'expected 18 skeleton sections, found %s\n' "${count}" >&2; return 1; }
  last="$(awk '/^## Step 3 /{f=1;next} /^## Step 4 /{f=0} f && /^[0-9]+\. \*\*/' "${SPEC_CMD}" | tail -1)"
  [[ "${last}" == 18.\ \*\*References\*\** ]] || { printf 'section 18 is not References: %s\n' "${last}" >&2; return 1; }
}

@test "spec-oneshot: the build prompt defines seven DONE items and the roles" {
  local block count
  block="$(awk '/^```$/{f=!f; next} f' "${SPEC_CMD}")"
  count="$(printf '%s\n' "${block}" | grep -cE '^[1-7]\. ')"
  [ "${count}" -eq 7 ] || { printf 'expected 7 DONE items in the build prompt, found %s\n' "${count}" >&2; return 1; }
  printf '%s\n' "${block}" | grep -q '^/goal '
  printf '%s\n' "${block}" | grep -q 'codex exec <CODEX_MODEL_FLAG> --skip-git-repo-check --sandbox read-only'
  printf '%s\n' "${block}" | grep -q 'There is no human'
}

@test "spec-oneshot: forbids TBD and asks Rob at most one round" {
  grep -qF 'never asks Rob more than one round' "${SPEC_CMD}"
  grep -qF '"TBD" is not' "${SPEC_CMD}"
}

@test "spec-oneshot: uses only Pocock skills and never Superpowers" {
  grep -qF 'Do not reference Superpowers skills' "${SPEC_CMD}"
  local s
  for s in domain-modeling grilling research to-spec code-review codebase-design to-tickets implement-spec tdd retro; do
    grep -q -- "${s}" "${SPEC_CMD}" || { printf 'spec-oneshot does not mention Pocock skill %s\n' "${s}" >&2; return 1; }
  done
}

# ------------------------------------------------------------------
# c-bpm-sk-gogo
# ------------------------------------------------------------------

@test "gogo: ships SKILL.md and the TEAMMATE.md contract it points to" {
  [ -f "${GOGO_DIR}/SKILL.md" ]
  [ -f "${GOGO_DIR}/TEAMMATE.md" ]
  grep -qF 'TEAMMATE.md' "${GOGO_DIR}/SKILL.md"
}

@test "gogo: is an unattended run that never asks a human and stops at 60 lead turns" {
  local flat; flat="$(tr '\n' ' ' < "${GOGO_DIR}/SKILL.md" | sed 's/  */ /g')"
  [[ "${flat}" == *"every decision goes to Codex, never to a human"* ]]
  [[ "${flat}" == *"reaches 60"* ]]
  [[ "${flat}" == *"Never commit to or merge into the default branch"* ]]
}

# ------------------------------------------------------------------
# spec-oneshot: team authoring, reviewer model, visible skill use (2026-10-23)
# ------------------------------------------------------------------

SPEC_CMD_FILE="${BATS_TEST_DIRNAME}/../../my/commands/c-bpm-cm-spec-oneshot.md"

section() { # <step number> -> body of that step
  awk -v n="$1" '$0 ~ "^## Step " n " "{f=1;next} /^## /{f=0} f' "${SPEC_CMD_FILE}"
}

@test "spec-oneshot: discovery is fanned out to parallel subagents" {
  local s; s="$(section 1)"
  [[ "${s}" == *"subagent"* ]]
  [[ "${s}" == *"in parallel"* ]]
}

@test "spec-oneshot: sections are drafted by a subagent team, the author integrates" {
  local s; s="$(section 3)"
  [[ "${s}" == *"drafting team"* ]]
  [[ "${s}" == *"Sections 11 and 13"* ]]
}

@test "spec-oneshot: the review runs as a team of parallel reviewers plus one whole-spec pass" {
  local s; s="$(section 6)"
  [[ "${s}" == *"review team"* ]]
  [[ "${s}" == *"whole-spec"* ]]
}

@test "spec-oneshot: --review-model is an argument, applied as codex exec -m, never hard-coded" {
  grep -qF -- '--review-model <model>' "${SPEC_CMD_FILE}"
  grep -qF -- 'codex exec -m <REVIEW_MODEL>' "${SPEC_CMD_FILE}"
}

@test "spec-oneshot: every Pocock skill is invoked with the Skill tool and listed in the report" {
  grep -qF 'with the Skill tool' "${SPEC_CMD_FILE}"
  local s; s="$(section 7)"
  [[ "${s}" == *"skills invoked"* ]]
}
