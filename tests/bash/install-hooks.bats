#!/usr/bin/env bats
#
# install-hooks.bats — behavioural tests for the install-hooks script.
#
# Every test drives the REAL script. Nothing greps the source: each assertion
# is about observable behaviour (exit code, files created/removed, settings.json
# content, log lines).
#
# Safety: nothing here can touch the real environment.
#   - $HOME is redirected to a temp dir for every test.
#   - The "system" prefix is redirected away from /usr/local/bin via the
#     script's INSTALL_HOOKS_SYSTEM_BIN_DIR seam. That seam CANNOT perform a
#     privileged write: install-hooks refuses --system whenever it is set
#     unless --dry-run is also given. The "SEAM" tests below assert exactly
#     that, so re-introducing a sudo/ownership bypass turns them red.
#   - The one test that runs --system against the REAL prefix skips as root
#     and only asserts the pre-write privilege refusal.
#   - install-hooks and its dist/ are copied into a temp sandbox repo, so the
#     script's own REPO_ROOT/dist resolution never reads the working tree.
#   - No sudo, no root, no writes outside $BATS_TEST_TMPDIR-style temp dirs.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPT_SRC="${REPO_ROOT}/install-hooks"
HOOK="issue-write-gate.mjs"

# ============================================================================
# Setup / Teardown
# ============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"

  # Sandbox repo (script + its own dist/ build).
  SANDBOX_REPO="${TEST_DIR}/repo"
  mkdir -p "${SANDBOX_REPO}/dist"
  cp "${SCRIPT_SRC}" "${SANDBOX_REPO}/install-hooks"
  chmod +x "${SANDBOX_REPO}/install-hooks"
  printf '// repo dist build — canonical\n' > "${SANDBOX_REPO}/dist/${HOOK}"
  SCRIPT="${SANDBOX_REPO}/install-hooks"

  # Sandbox HOME.
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}/.claude" "${HOME}/.config/claude"
  CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
  CONFIG_SETTINGS="${HOME}/.config/claude/settings.json"
  printf '{}\n' > "${CLAUDE_SETTINGS}"
  printf '{}\n' > "${CONFIG_SETTINGS}"

  # Sandbox "system" prefix (test-only knob — see install-hooks header).
  export INSTALL_HOOKS_SYSTEM_BIN_DIR="${TEST_DIR}/sysbin"
  mkdir -p "${INSTALL_HOOKS_SYSTEM_BIN_DIR}"

  USER_HOOK="${HOME}/.claude/hooks/dist/${HOOK}"
  SYS_HOOK="${INSTALL_HOOKS_SYSTEM_BIN_DIR}/${HOOK}"
}

teardown() {
  [ -n "${TEST_DIR:-}" ] && rm -rf "${TEST_DIR}"
  return 0
}

# ============================================================================
# Helpers
# ============================================================================

# Count hook entries for $HOOK across every matcher in a settings file.
hook_entry_count() {
  jq '[ (.hooks.PreToolUse // [])[] | (.hooks // [])[] | .command
        | select(contains("'"${HOOK}"'")) ] | length' "$1"
}

# Build a PATH directory containing every binary install-hooks needs, minus the
# ones named in $2.. — used to prove a dependency really is (or is not)
# required on a given code path.
make_bin_without() {
  local d="$1"; shift
  local excluded=" $* " b p
  mkdir -p "$d"
  for b in bash sh env cat sed awk jq cmp mktemp mv date cp rm mkdir ln \
           readlink chmod install id dirname basename sha256sum grep sort tr \
           node sudo sleep find stat wc; do
    case "$excluded" in *" $b "*) continue ;; esac
    p="$(command -v "$b" 2>/dev/null || true)"
    if [ -n "$p" ]; then ln -sf "$p" "$d/$b"; fi
  done
}

make_nodeless_bin() { make_bin_without "$1" node; }

# Build a jq shim used to exercise the atomic-write failure path (#75).
#   JQ_SHIM_MARKER  — if set, append the resolved stdout path of each merge call
#   JQ_SHIM_FAIL=1  — make each merge call fail (simulated jq/merge failure)
#   JQ_SHIM_SIGNAL  — signal name (TERM/INT) to send to install-hooks itself
#                     mid-write, after emitting a partial temp file
# The read-only probes install-hooks makes (`jq -e .` validity check and
# `jq -r` matcher discovery) always delegate to the real jq so the script
# reaches the merge step.
make_jq_shim() {
  local d="$1" realjq
  realjq="$(command -v jq)"
  mkdir -p "$d"
  cat > "$d/jq" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "-e" ] || [ "\$1" = "-r" ]; then exec "${realjq}" "\$@"; fi
if [ -n "\${JQ_SHIM_MARKER:-}" ]; then
  # Duplicate our own stdout to fd 9 first: inside the command substitution
  # below fd 1 is the substitution pipe, so /proc/self/fd/1 would resolve to
  # the wrong thing. fd 9 still points at the file install-hooks redirected
  # our stdout to, i.e. the settings temp file.
  exec 9>&1
  __out="\$(readlink -f /proc/self/fd/9)"
  exec 9>&-
  printf '%s\n' "\${__out}" >> "\${JQ_SHIM_MARKER}"
fi
if [ -n "\${JQ_SHIM_SIGNAL:-}" ]; then
  # Emit a real partial write into the temp file, then signal install-hooks
  # (our parent) while it is mid-write. bash runs its trap once we exit.
  printf '{"truncated-partial-write":'
  kill -"\${JQ_SHIM_SIGNAL}" "\$PPID"
  exit 0
fi
if [ "\${JQ_SHIM_FAIL:-0}" = "1" ]; then echo "simulated jq merge failure" >&2; exit 5; fi
exec "${realjq}" "\$@"
EOF
  chmod +x "$d/jq"
}

# Multi-matcher fixture for #83: three matchers hold the hook, and the Bash
# block additionally holds an unrelated hook that must survive.
write_multi_matcher_settings() {
  cat > "$1" <<'JSON'
{
  "otherKey": "preserve-me",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "node /old/path/issue-write-gate.mjs", "timeout": 10 },
          { "type": "command", "command": "node /old/path/unrelated-hook.mjs", "timeout": 5 }
        ]
      },
      {
        "matcher": "mcp__github__issue_write",
        "hooks": [
          { "type": "command", "command": "node /old/path/issue-write-gate.mjs", "timeout": 10 }
        ]
      },
      {
        "matcher": "mcp__github__create_issue",
        "hooks": [
          { "type": "command", "command": "node /old/path/issue-write-gate.mjs", "timeout": 10 }
        ]
      }
    ]
  }
}
JSON
}

# ============================================================================
# Baseline / smoke
# ============================================================================

@test "bash -n syntax check passes" {
  run bash -n "${SCRIPT}"
  [ "$status" -eq 0 ]
}

@test "plain per-user install registers the hook on all three matchers in both settings files" {
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 3 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -eq 3 ]
  [ -f "${USER_HOOK}" ]
}

@test "re-running the install is idempotent" {
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 3 ]
  [[ "$output" == *"already up to date"* ]]
}

# ============================================================================
# Issue #82 — fail-closed checksum verification of the system copy
# ============================================================================

@test "#82 per-user install REFUSES to symlink a checksum-mismatched system copy" {
  printf '// TAMPERED build\n' > "${SYS_HOOK}"

  run "${SCRIPT}"

  # Behaviour, not log text: non-zero exit and no link created.
  [ "$status" -ne 0 ]
  [ ! -e "${USER_HOOK}" ]
  [ ! -L "${USER_HOOK}" ]
}

@test "#82 refusal happens before settings.json is touched" {
  printf '// TAMPERED build\n' > "${SYS_HOOK}"
  cp "${CLAUDE_SETTINGS}" "${TEST_DIR}/settings.before"

  run "${SCRIPT}"

  [ "$status" -ne 0 ]
  run cmp -s "${TEST_DIR}/settings.before" "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]
}

@test "#82 matching checksum DOES produce the symlink to the system copy" {
  cp "${SANDBOX_REPO}/dist/${HOOK}" "${SYS_HOOK}"

  run "${SCRIPT}"

  [ "$status" -eq 0 ]
  [ -L "${USER_HOOK}" ]
  [ "$(readlink "${USER_HOOK}")" = "${SYS_HOOK}" ]
}

@test "#82 --force is the bypass: mismatched system copy is linked anyway, exit 0" {
  printf '// TAMPERED build\n' > "${SYS_HOOK}"

  run "${SCRIPT}" --force

  [ "$status" -eq 0 ]
  [ -L "${USER_HOOK}" ]
  [ "$(readlink "${USER_HOOK}")" = "${SYS_HOOK}" ]
}

@test "#82 a system copy that drifts AFTER a good install is still caught on re-run" {
  cp "${SANDBOX_REPO}/dist/${HOOK}" "${SYS_HOOK}"
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -L "${USER_HOOK}" ]

  # System copy drifts; the "already symlinked" shortcut must not skip verify.
  printf '// DRIFTED afterwards\n' > "${SYS_HOOK}"
  run "${SCRIPT}"
  [ "$status" -ne 0 ]
}

@test "#82 --dry-run also fails closed on a mismatched system copy" {
  printf '// TAMPERED build\n' > "${SYS_HOOK}"

  run "${SCRIPT}" --dry-run

  [ "$status" -ne 0 ]
  [ ! -e "${USER_HOOK}" ]
}

@test "#82 checksum logic is skipped in --uninstall mode (mismatch does not block removal)" {
  cp "${SANDBOX_REPO}/dist/${HOOK}" "${SYS_HOOK}"
  run "${SCRIPT}"
  [ "$status" -eq 0 ]

  printf '// TAMPERED build\n' > "${SYS_HOOK}"

  run "${SCRIPT}" --uninstall

  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 0 ]
  [ ! -e "${USER_HOOK}" ]
  [ ! -L "${USER_HOOK}" ]
}

# ============================================================================
# Issue #83 — matcher-scoped uninstall: one pass, one consolidated log line
# ============================================================================

@test "#83 uninstall removes the hook from ALL matchers in a single pass" {
  write_multi_matcher_settings "${CLAUDE_SETTINGS}"

  run "${SCRIPT}" --uninstall

  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 0 ]
  # Emptied matcher blocks are dropped; the Bash block survives for its
  # unrelated hook only.
  [ "$(jq '.hooks.PreToolUse | length' "${CLAUDE_SETTINGS}")" -eq 1 ]
  [ "$(jq -r '.hooks.PreToolUse[0].matcher' "${CLAUDE_SETTINGS}")" = "Bash" ]
  [ "$(jq -r '.hooks.PreToolUse[0].hooks | length' "${CLAUDE_SETTINGS}")" -eq 1 ]
  [[ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "${CLAUDE_SETTINGS}")" == *"unrelated-hook.mjs"* ]]
  # Unrelated top-level keys preserved.
  [ "$(jq -r '.otherKey' "${CLAUDE_SETTINGS}")" = "preserve-me" ]
}

@test "#83 uninstall logs exactly ONE consolidated line naming every affected matcher" {
  write_multi_matcher_settings "${CLAUDE_SETTINGS}"

  run "${SCRIPT}" --uninstall
  [ "$status" -eq 0 ]

  local removed_lines
  removed_lines="$(printf '%s\n' "$output" | grep -c "REMOVED ${HOOK}" || true)"
  [ "$removed_lines" -eq 1 ]

  local line
  line="$(printf '%s\n' "$output" | grep "REMOVED ${HOOK}")"
  [[ "$line" == *"Bash"* ]]
  [[ "$line" == *"mcp__github__issue_write"* ]]
  [[ "$line" == *"mcp__github__create_issue"* ]]
}

@test "#83 uninstall on a settings file with no matching entries logs no removal at all" {
  # CONFIG_SETTINGS is '{}' and CLAUDE_SETTINGS has only an unrelated hook.
  cat > "${CLAUDE_SETTINGS}" <<'JSON'
{ "hooks": { "PreToolUse": [
  { "matcher": "Bash", "hooks": [ { "type": "command", "command": "node /x/unrelated-hook.mjs", "timeout": 5 } ] }
] } }
JSON

  run "${SCRIPT}" --uninstall

  [ "$status" -eq 0 ]
  [[ "$output" != *"REMOVED ${HOOK}"* ]]
  [ "$(jq '.hooks.PreToolUse | length' "${CLAUDE_SETTINGS}")" -eq 1 ]
}

@test "#83 --uninstall --dry-run reports the matchers but changes nothing" {
  write_multi_matcher_settings "${CLAUDE_SETTINGS}"
  cp "${CLAUDE_SETTINGS}" "${TEST_DIR}/settings.before"

  run "${SCRIPT}" --uninstall --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"would REMOVE ${HOOK}"* ]]
  run cmp -s "${TEST_DIR}/settings.before" "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Issue #84 — --uninstall must not require node
# ============================================================================

@test "#84 uninstall completes with node absent from PATH" {
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 3 ]

  local nlbin="${TEST_DIR}/nodeless-bin"
  make_nodeless_bin "${nlbin}"

  # Prove node is genuinely unreachable under this PATH.
  run env PATH="${nlbin}" bash -c 'command -v node'
  [ "$status" -ne 0 ]

  run env PATH="${nlbin}" "${SCRIPT}" --uninstall

  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 0 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -eq 0 ]
  [ ! -e "${USER_HOOK}" ]
}

@test "#84 install (non-uninstall) still fails loudly when node is absent" {
  local nlbin="${TEST_DIR}/nodeless-bin"
  make_nodeless_bin "${nlbin}"

  run env PATH="${nlbin}" "${SCRIPT}"

  [ "$status" -ne 0 ]
  [[ "$output" == *"node"* ]]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 0 ]
}

@test "#84 --uninstall --system completes with node absent from PATH" {
  cp "${SANDBOX_REPO}/dist/${HOOK}" "${SYS_HOOK}"
  local nlbin="${TEST_DIR}/nodeless-bin"
  make_nodeless_bin "${nlbin}"

  # --dry-run because the prefix override refuses privileged --system work;
  # the node requirement is checked long before either, so this still proves
  # the uninstall path never demands node.
  run env PATH="${nlbin}" "${SCRIPT}" --uninstall --system --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"would remove"* ]]
}

# ============================================================================
# Issue #81 — system uninstall must detect symlinks and dangling symlinks
# ============================================================================

# Both uninstall branches share one predicate (hook_path_present), so the
# real-removal tests below (per-user branch, unprivileged) and the detection
# tests (system branch, --dry-run) together cover the fix without any
# privileged write.

@test "#81 per-user uninstall REALLY removes a LIVE symlink" {
  local target="${TEST_DIR}/elsewhere.mjs"
  printf '// somewhere else\n' > "${target}"
  mkdir -p "$(dirname "${USER_HOOK}")"
  ln -s "${target}" "${USER_HOOK}"
  [ -L "${USER_HOOK}" ]

  run "${SCRIPT}" --uninstall

  [ "$status" -eq 0 ]
  [ ! -e "${USER_HOOK}" ]
  [ ! -L "${USER_HOOK}" ]
  # Only the link goes; the symlink target is left alone.
  [ -f "${target}" ]
}

@test "#81 per-user uninstall REALLY removes a DANGLING symlink" {
  mkdir -p "$(dirname "${USER_HOOK}")"
  ln -s "${TEST_DIR}/does-not-exist.mjs" "${USER_HOOK}"
  [ -L "${USER_HOOK}" ]
  [ ! -e "${USER_HOOK}" ]

  run "${SCRIPT}" --uninstall

  [ "$status" -eq 0 ]
  [ ! -L "${USER_HOOK}" ]
}

@test "#81 system branch detects a LIVE symlink" {
  local target="${TEST_DIR}/elsewhere.mjs"
  printf '// somewhere else\n' > "${target}"
  ln -s "${target}" "${SYS_HOOK}"

  run "${SCRIPT}" --uninstall --system --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"would remove"* ]]
  [ -L "${SYS_HOOK}" ]
}

@test "#81 system branch detects a DANGLING symlink (the -f bug)" {
  ln -s "${TEST_DIR}/does-not-exist.mjs" "${SYS_HOOK}"
  [ -L "${SYS_HOOK}" ]
  [ ! -e "${SYS_HOOK}" ]

  run "${SCRIPT}" --uninstall --system --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"would remove"* ]]
  [ -L "${SYS_HOOK}" ]
}

@test "#81 system branch detects a plain regular file" {
  cp "${SANDBOX_REPO}/dist/${HOOK}" "${SYS_HOOK}"

  run "${SCRIPT}" --uninstall --system --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"would remove"* ]]
}

@test "#81 system branch reports nothing when the path is absent (negative control)" {
  [ ! -e "${SYS_HOOK}" ]

  run "${SCRIPT}" --uninstall --system --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" != *"would remove"* ]]
}

# ============================================================================
# Privilege seam — INSTALL_HOOKS_SYSTEM_BIN_DIR must never weaken --system
# ============================================================================

@test "SEAM prefix override REFUSES a real --system install (no ownership downgrade)" {
  # If someone re-adds a "sandbox mode" that installs unprivileged without
  # root:root, this goes green-to-red: the install would succeed.
  run "${SCRIPT}" --system

  [ "$status" -ne 0 ]
  [ ! -e "${SYS_HOOK}" ]
}

@test "SEAM prefix override REFUSES a real --system uninstall (no sudo bypass)" {
  printf '// planted\n' > "${SYS_HOOK}"

  run "${SCRIPT}" --uninstall --system

  [ "$status" -ne 0 ]
  # Refused before any removal: the planted file is untouched.
  [ -f "${SYS_HOOK}" ]
}

@test "SEAM prefix override is allowed only with --dry-run, and writes nothing" {
  run "${SCRIPT}" --system --dry-run

  [ "$status" -eq 0 ]
  [ ! -e "${SYS_HOOK}" ]
}

@test "SEAM --system still declares root:root ownership under the override" {
  run "${SCRIPT}" --system --dry-run

  [ "$status" -eq 0 ]
  # A re-introduced sandbox branch would drop root:root from the plan.
  [[ "$output" == *"root:root"* ]]
}

@test "SEAM the root/sudo requirement for --system is unconditional" {
  if [ "$(id -u)" -eq 0 ]; then
    skip "running as root would exercise the real /usr/local/bin"
  fi
  # No override: the real privilege check must fire on the real prefix, and
  # must fail before anything is written when neither root nor sudo is available.
  local nosudo="${TEST_DIR}/nosudo-bin"
  make_bin_without "${nosudo}" sudo

  run env -u INSTALL_HOOKS_SYSTEM_BIN_DIR PATH="${nosudo}" "${SCRIPT}" --system

  [ "$status" -ne 0 ]
  [[ "$output" == *"requires root or sudo"* ]]
}

# ============================================================================
# Issue #76 — --ensure-both (opt-in creation of missing settings paths)
# ============================================================================

@test "#76 WITHOUT --ensure-both a missing settings path is not created" {
  rm -rf "${HOME}/.config"

  run "${SCRIPT}"

  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.config" ]
  [ ! -f "${CONFIG_SETTINGS}" ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 3 ]
}

@test "#76 --ensure-both creates the missing parent dir and settings.json, with hooks registered" {
  rm -rf "${HOME}/.config"

  run "${SCRIPT}" --ensure-both

  [ "$status" -eq 0 ]
  [ -d "${HOME}/.config/claude" ]
  [ -f "${CONFIG_SETTINGS}" ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -eq 3 ]
}

@test "#76 --ensure-both does NOT clobber an existing settings.json" {
  cat > "${CLAUDE_SETTINGS}" <<'JSON'
{ "customKey": "keep-me", "hooks": { "PostToolUse": [ { "matcher": "Bash", "hooks": [] } ] } }
JSON

  run "${SCRIPT}" --ensure-both

  [ "$status" -eq 0 ]
  [ "$(jq -r '.customKey' "${CLAUDE_SETTINGS}")" = "keep-me" ]
  [ "$(jq '.hooks.PostToolUse | length' "${CLAUDE_SETTINGS}")" -eq 1 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 3 ]
}

@test "#76 --ensure-both --dry-run creates nothing" {
  rm -rf "${HOME}/.config"

  run "${SCRIPT}" --ensure-both --dry-run

  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.config" ]
}

@test "#76 --ensure-both is ignored under --uninstall (creates nothing)" {
  rm -rf "${HOME}/.config"

  run "${SCRIPT}" --uninstall --ensure-both

  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.config" ]
}

# ============================================================================
# Issue #75 — atomic settings.json write (mktemp in target dir + mv + trap)
# ============================================================================

@test "#75 a merge failure leaves settings.json byte-identical and no temp file behind" {
  cat > "${CLAUDE_SETTINGS}" <<'JSON'
{ "customKey": "original-content", "hooks": {} }
JSON
  cp "${CLAUDE_SETTINGS}" "${TEST_DIR}/settings.before"

  local shim="${TEST_DIR}/jqshim"
  make_jq_shim "${shim}"

  run env PATH="${shim}:${PATH}" JQ_SHIM_FAIL=1 "${SCRIPT}"

  # Fails, and the original file is untouched byte-for-byte.
  [ "$status" -ne 0 ]
  run cmp -s "${TEST_DIR}/settings.before" "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]

  # The trap removed the in-flight temp file.
  local leftovers
  leftovers="$(find "${HOME}" -name '.install-hooks.settings.*' | wc -l)"
  [ "$leftovers" -eq 0 ]
}

@test "#75 SIGTERM mid-write leaves settings.json byte-identical and no temp file behind" {
  cat > "${CLAUDE_SETTINGS}" <<'JSON'
{ "customKey": "original-content", "hooks": {} }
JSON
  cp "${CLAUDE_SETTINGS}" "${TEST_DIR}/settings.before"

  local shim="${TEST_DIR}/jqshim"
  make_jq_shim "${shim}"

  # The shim writes a partial JSON fragment into the temp file, then sends a
  # real SIGTERM to install-hooks while it is mid-write.
  #
  # What this test discriminates (measured, not assumed): the TERM path is
  # covered TWICE — bash's fatal-signal handler runs the EXIT trap even with no
  # TERM trap installed, and the explicit TERM trap covers it when EXIT is gone.
  # Removing either one alone keeps this green; removing both turns it red. So
  # this asserts the #75 property (no corruption, no leftover) rather than any
  # single trap line. The SIGINT test below is the one that pins its own trap:
  # without the INT trap bash resumes the script after the signal and commits
  # the partial temp file, so that test goes red on its own.
  run env PATH="${shim}:${PATH}" JQ_SHIM_SIGNAL=TERM "${SCRIPT}"

  [ "$status" -ne 0 ]

  run cmp -s "${TEST_DIR}/settings.before" "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]

  # If the TERM trap had not run, the partial temp file would still be here.
  local leftovers
  leftovers="$(find "${HOME}" -name '.install-hooks.settings.*' | wc -l)"
  [ "$leftovers" -eq 0 ]
}

@test "#75 SIGINT mid-write leaves settings.json byte-identical and no temp file behind" {
  cat > "${CLAUDE_SETTINGS}" <<'JSON'
{ "customKey": "original-content", "hooks": {} }
JSON
  cp "${CLAUDE_SETTINGS}" "${TEST_DIR}/settings.before"

  local shim="${TEST_DIR}/jqshim"
  make_jq_shim "${shim}"

  run env PATH="${shim}:${PATH}" JQ_SHIM_SIGNAL=INT "${SCRIPT}"

  [ "$status" -ne 0 ]

  run cmp -s "${TEST_DIR}/settings.before" "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]

  local leftovers
  leftovers="$(find "${HOME}" -name '.install-hooks.settings.*' | wc -l)"
  [ "$leftovers" -eq 0 ]
}

@test "#75 the temp file is created in the SAME directory as the target settings.json" {
  local shim="${TEST_DIR}/jqshim"
  local marker="${TEST_DIR}/tmp-paths.txt"
  make_jq_shim "${shim}"

  run env PATH="${shim}:${PATH}" JQ_SHIM_MARKER="${marker}" "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -s "${marker}" ]

  # Every merge wrote into the directory of the settings file it was merging,
  # which is what makes the subsequent mv an atomic same-filesystem rename.
  local p
  while read -r p; do
    case "$(dirname "$p")" in
      "${HOME}/.claude"|"${HOME}/.config/claude") ;;
      *) echo "temp file outside target dir: $p"; return 1 ;;
    esac
  done < "${marker}"
}

@test "#75 a successful write preserves the settings.json file mode" {
  chmod 0644 "${CLAUDE_SETTINGS}"

  run "${SCRIPT}"

  [ "$status" -eq 0 ]
  [ "$(stat -c '%a' "${CLAUDE_SETTINGS}")" = "644" ]
}

@test "#75 a successful install leaves no temp files behind" {
  run "${SCRIPT}"

  [ "$status" -eq 0 ]
  local leftovers
  leftovers="$(find "${HOME}" -name '.install-hooks.settings.*' | wc -l)"
  [ "$leftovers" -eq 0 ]
}

@test "#75 settings.json stays valid JSON across install and uninstall" {
  run "${SCRIPT}"
  [ "$status" -eq 0 ]
  run jq -e . "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]

  run "${SCRIPT}" --uninstall
  [ "$status" -eq 0 ]
  run jq -e . "${CLAUDE_SETTINGS}"
  [ "$status" -eq 0 ]
}
