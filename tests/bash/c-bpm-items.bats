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
POCOCK_CMD="${REPO_ROOT}/my/commands/c-bpm-cm-pocock-update.md"
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
  printf '%s\n' "${block}" | grep -q 'codex exec --skip-git-repo-check --sandbox read-only'
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
# c-bpm-cm-pocock-update
# ------------------------------------------------------------------

pocock_script() {
  awk '/^```bash$/{f=1; next} /^```$/{f=0} f' "${POCOCK_CMD}"
}

@test "pocock-update: the embedded script parses" {
  local tmp; tmp="$(mktemp)"
  pocock_script > "${tmp}"
  [ -s "${tmp}" ] || { echo "no bash block found" >&2; rm -f "${tmp}"; return 1; }
  bash -n "${tmp}"
  local rc=$?
  rm -f "${tmp}"
  return "${rc}"
}

@test "pocock-update: strips the lock line from the frontmatter only, idempotently" {
  command -v python3 >/dev/null || skip "python3 not on PATH"
  local d; d="$(mktemp -d)"
  mkdir -p "${d}/skills/a" "${d}/skills/b"
  printf -- '---\nname: a\ndisable-model-invocation: true\ndescription: x\n---\n\nbody mentions disable-model-invocation: true as text\n' > "${d}/skills/a/SKILL.md"
  printf -- '---\nname: b\ndescription: y\n---\n\nbody\n' > "${d}/skills/b/SKILL.md"
  # Extract only the python unlock snippet from the script and run it per file.
  local py; py="$(pocock_script | awk '/python3 -I - "\$f" <<.PY.$/{f=1; next} /^PY$/{f=0} f')"
  [ -n "${py}" ] || { echo "unlock snippet not found" >&2; rm -rf "${d}"; return 1; }
  printf '%s\n' "${py}" | python3 -I - "${d}/skills/a/SKILL.md"
  printf '%s\n' "${py}" | python3 -I - "${d}/skills/a/SKILL.md"
  printf '%s\n' "${py}" | python3 -I - "${d}/skills/b/SKILL.md"
  local a b
  a="$(cat "${d}/skills/a/SKILL.md")"; b="$(cat "${d}/skills/b/SKILL.md")"
  rm -rf "${d}"
  [ "${a}" = "$(printf -- '---\nname: a\ndescription: x\n---\n\nbody mentions disable-model-invocation: true as text')" ] || { printf 'unexpected a:\n%s\n' "${a}" >&2; return 1; }
  [ "${b}" = "$(printf -- '---\nname: b\ndescription: y\n---\n\nbody')" ] || { printf 'unexpected b:\n%s\n' "${b}" >&2; return 1; }
}

@test "pocock-update: never touches the marketplace clone" {
  ! pocock_script | grep -q 'plugins/marketplaces'
  grep -qF 'never edits the marketplace clone' "${POCOCK_CMD}"
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

# End-to-end: run the embedded script against a fake HOME with --no-update.
# Reproduces the review finding that `grep | wc -l` under pipefail aborted
# the script once no skill was locked any more (the success case).
pocock_fake_home() { # <dir> <locked-count>
  local home="$1" locked="$2" i
  mkdir -p "${home}/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9/skills"
  for i in 1 2 3; do
    mkdir -p "${home}/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9/skills/s${i}"
    if [ "${i}" -le "${locked}" ]; then
      printf -- '---\nname: s%s\ndisable-model-invocation: true\n---\nbody\n' "${i}"
    else
      printf -- '---\nname: s%s\n---\nbody\n' "${i}"
    fi > "${home}/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9/skills/s${i}/SKILL.md"
  done
  printf '{"version":1,"plugins":{"mattpocock-skills@mattpocock":[{"version":"9.9.9","installPath":"%s/.claude/plugins/cache/mattpocock/mattpocock-skills/9.9.9"}]}}' "${home}" \
    > "${home}/.claude/plugins/installed_plugins.json"
  printf '{"version":"9.9.9"}' > "${home}/manifest.json"
}

@test "pocock-update: --no-update unlocks locked skills and prints the table" {
  local home; home="$(mktemp -d)"; pocock_fake_home "${home}" 2
  local script; script="$(mktemp)"; pocock_script > "${script}"
  run env HOME="${home}" POCOCK_MANIFEST_URL="file://${home}/manifest.json" bash "${script}" --no-update
  rm -f "${script}"
  [ "${status}" -eq 0 ] || { printf 'exit %s\n%s\n' "${status}" "${output}" >&2; rm -rf "${home}"; return 1; }
  [[ "${output}" == *"| unlocked this run | 2 |"* ]]
  [[ "${output}" == *"| still locked | 0 |"* ]]
  [ "$(grep -rl 'disable-model-invocation' "${home}/.claude/plugins/cache" | wc -l)" -eq 0 ]
  rm -rf "${home}"
}

@test "pocock-update: --no-update with nothing locked exits 0 and prints the table (pipefail regression)" {
  local home; home="$(mktemp -d)"; pocock_fake_home "${home}" 0
  local script; script="$(mktemp)"; pocock_script > "${script}"
  run env HOME="${home}" POCOCK_MANIFEST_URL="file://${home}/manifest.json" bash "${script}" --no-update
  rm -f "${script}"
  [ "${status}" -eq 0 ] || { printf 'exit %s\n%s\n' "${status}" "${output}" >&2; rm -rf "${home}"; return 1; }
  [[ "${output}" == *"| unlocked this run | 0 |"* ]]
  [[ "${output}" == *"| still locked | 0 |"* ]]
  rm -rf "${home}"
}

@test "pocock-update: --check with nothing locked exits 0 (pipefail regression)" {
  local home; home="$(mktemp -d)"; pocock_fake_home "${home}" 0
  local script; script="$(mktemp)"; pocock_script > "${script}"
  run env HOME="${home}" POCOCK_MANIFEST_URL="file://${home}/manifest.json" bash "${script}" --check
  rm -f "${script}"; rm -rf "${home}"
  [ "${status}" -eq 0 ] || { printf 'exit %s\n%s\n' "${status}" "${output}" >&2; return 1; }
  [[ "${output}" == *"| locked skills | 0 |"* ]]
}
