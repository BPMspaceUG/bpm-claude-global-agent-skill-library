#!/usr/bin/env bats
#
# my-bpm-library-compare.bats - Tests for my-bpm-library-compare
# Run with: bats tests/bash/my-bpm-library-compare.bats
#
# Safety:
# - All tests use isolated temp directories simulating repo + local
# - No real ~/.claude or git repos are touched
# - Tests override HOME and REPO_DIR to use temp directories

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
COMPARE="${REPO_ROOT}/my-bpm-library-compare"

# ============================================================================
# Setup / Teardown
# ============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"

  # Create a fake HOME with .claude structure
  FAKE_HOME="${TEST_DIR}/home"
  mkdir -p "${FAKE_HOME}/.claude"
  echo '{}' > "${FAKE_HOME}/.claude/settings.json"
  mkdir -p "${FAKE_HOME}/.claude/skills"
  mkdir -p "${FAKE_HOME}/.claude/agents"
  mkdir -p "${FAKE_HOME}/.claude/commands"
  mkdir -p "${FAKE_HOME}/.claude/runbooks"

  # Create a fake repo
  FAKE_REPO="${FAKE_HOME}/bpm-claude-global-agent-skill-library"
  mkdir -p "${FAKE_REPO}/.git"
  mkdir -p "${FAKE_REPO}/my/skills"
  mkdir -p "${FAKE_REPO}/my/agents"
  mkdir -p "${FAKE_REPO}/my/commands"
  mkdir -p "${FAKE_REPO}/my/runbooks"

  # Copy lib.sh to fake repo (so source works)
  cp "${REPO_ROOT}/lib.sh" "${FAKE_REPO}/lib.sh"

  # Create a wrapper script that overrides HOME
  WRAPPER="${TEST_DIR}/compare-wrapper"
  cat > "${WRAPPER}" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
export HOME="${FAKE_HOME}"
# Patch the script to source lib.sh from the fake repo
exec bash "${COMPARE}" "\$@"
SCRIPT
  chmod +x "${WRAPPER}"

  # We need to create a modified copy of the compare script that uses our fake HOME
  PATCHED="${TEST_DIR}/my-bpm-library-compare"
  sed "s|REPO_DIR=\"\$HOME/\$REPO_NAME\"|REPO_DIR=\"${FAKE_REPO}\"|" "${COMPARE}" > "${PATCHED}"
  # Also patch lib.sh source to use the fake repo's lib.sh
  sed -i "s|source \"\$(dirname \"\$(readlink -f \"\$0\")\")/lib.sh\"|source \"${FAKE_REPO}/lib.sh\"|" "${PATCHED}"
  chmod +x "${PATCHED}"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

# Helper: create a skill in the local dir
create_local_skill() {
  local name="$1"
  local content="${2:-default content}"
  mkdir -p "${FAKE_HOME}/.claude/skills/${name}"
  echo "$content" > "${FAKE_HOME}/.claude/skills/${name}/SKILL.md"
}

# Helper: create a skill in the repo
create_repo_skill() {
  local name="$1"
  local content="${2:-default content}"
  mkdir -p "${FAKE_REPO}/my/skills/${name}"
  echo "$content" > "${FAKE_REPO}/my/skills/${name}/SKILL.md"
}

# Helper: create an agent in the local dir
create_local_agent() {
  local name="$1"
  local content="${2:-default agent content}"
  echo "$content" > "${FAKE_HOME}/.claude/agents/${name}"
}

# Helper: create an agent in the repo
create_repo_agent() {
  local name="$1"
  local content="${2:-default agent content}"
  echo "$content" > "${FAKE_REPO}/my/agents/${name}"
}

# ============================================================================
# Basic Tests
# ============================================================================

@test "bash -n syntax check passes" {
  run bash -n "${COMPARE}"
  [ "$status" -eq 0 ]
}

@test "--help exits 0 with usage text" {
  run bash "${COMPARE}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"my-bpm-library-compare"* ]]
}

@test "--version exits 0 with version string" {
  run bash "${COMPARE}" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-bpm-library-compare v"* ]]
}

@test "--help shows symbol legend" {
  run bash "${COMPARE}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"L  local only"* ]]
  [[ "$output" == *"R  repo only"* ]]
  [[ "$output" == *"~  modified"* ]]
  [[ "$output" == *"=  identical"* ]]
}

@test "unknown option exits non-zero" {
  run bash "${COMPARE}" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

# ============================================================================
# Comparison Tests (using patched script with fake HOME)
# ============================================================================

@test "empty directories show everything in sync" {
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Everything is in sync"* ]]
}

@test "local-only skill shows L symbol" {
  create_local_skill "my-bpm-test-local"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"L  skills/my-bpm-test-local"* ]]
}

@test "repo-only skill shows R symbol" {
  create_repo_skill "my-bpm-test-repo"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"R  skills/my-bpm-test-repo"* ]]
}

@test "identical skill is counted but not displayed without --verbose" {
  create_local_skill "my-bpm-test-same" "identical content"
  create_repo_skill "my-bpm-test-same" "identical content"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"Identical:   1"* ]]
  [[ "$output" != *"L  skills/my-bpm-test-same"* ]]
  [[ "$output" != *"R  skills/my-bpm-test-same"* ]]
}

@test "identical skill shows = with --verbose" {
  create_local_skill "my-bpm-test-same" "identical content"
  create_repo_skill "my-bpm-test-same" "identical content"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"=  skills/my-bpm-test-same"* ]]
}

@test "modified skill shows ~ symbol" {
  create_local_skill "my-bpm-test-diff" "local version"
  create_repo_skill "my-bpm-test-diff" "repo version"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"~  skills/my-bpm-test-diff"* ]]
}

@test "local-only agent shows L symbol" {
  create_local_agent "my-bpm-test-agent.md"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-agents
  [ "$status" -eq 0 ]
  [[ "$output" == *"L  agents/my-bpm-test-agent.md"* ]]
}

@test "repo-only agent shows R symbol" {
  create_repo_agent "my-bpm-test-agent.md"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-agents
  [ "$status" -eq 0 ]
  [[ "$output" == *"R  agents/my-bpm-test-agent.md"* ]]
}

@test "--only-skills filters to skills only" {
  create_local_skill "my-bpm-test-skill"
  create_local_agent "my-bpm-test-agent.md"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"skills/my-bpm-test-skill"* ]]
  [[ "$output" != *"agents/my-bpm-test-agent"* ]]
}

@test "--only-agents filters to agents only" {
  create_local_skill "my-bpm-test-skill"
  create_local_agent "my-bpm-test-agent.md"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-agents
  [ "$status" -eq 0 ]
  [[ "$output" != *"skills/my-bpm-test-skill"* ]]
  [[ "$output" == *"agents/my-bpm-test-agent"* ]]
}

@test "summary counts are correct" {
  create_local_skill "my-bpm-local-only"
  create_repo_skill "my-bpm-repo-only"
  create_local_skill "my-bpm-modified" "local"
  create_repo_skill "my-bpm-modified" "repo"
  create_local_skill "my-bpm-same" "same"
  create_repo_skill "my-bpm-same" "same"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --only-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"Local only:  1"* ]]
  [[ "$output" == *"Repo only:   1"* ]]
  [[ "$output" == *"Modified:    1"* ]]
  [[ "$output" == *"Identical:   1"* ]]
}

# ============================================================================
# Dry-run / Repair Tests
# ============================================================================

@test "--dry-run shows repair plan without changes" {
  create_local_skill "my-bpm-local-only"
  create_repo_skill "my-bpm-repo-only"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repair plan:"* ]]
  [[ "$output" == *"DRY RUN - No changes made"* ]]
  # Verify nothing was actually copied
  [ ! -d "${FAKE_HOME}/.claude/skills/my-bpm-repo-only" ]
  [ ! -d "${FAKE_REPO}/my/skills/my-bpm-local-only" ]
}

@test "--dry-run shows pull and push sections" {
  create_local_skill "my-bpm-local-only"
  create_repo_skill "my-bpm-repo-only"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pull from repo to local:"* ]]
  [[ "$output" == *"<- skills/my-bpm-repo-only"* ]]
  [[ "$output" == *"Push from local to repo:"* ]]
  [[ "$output" == *"-> skills/my-bpm-local-only"* ]]
}

@test "--dry-run shows modified items as requiring manual resolution" {
  create_local_skill "my-bpm-changed" "local"
  create_repo_skill "my-bpm-changed" "repo"
  export HOME="${FAKE_HOME}"
  run bash "${PATCHED}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"!! skills/my-bpm-changed"* ]]
}

@test "repair prompt offers pull/push/both/skip options" {
  create_repo_skill "my-bpm-repo-only"
  export HOME="${FAKE_HOME}"
  # Feed "skip" to stdin
  run bash "${PATCHED}" --repair <<< "skip"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull"* ]]
  [[ "$output" == *"push"* ]]
  [[ "$output" == *"both"* ]]
  [[ "$output" == *"skip"* ]]
}

@test "script requires git and diff" {
  run grep 'require_commands.*git.*diff' "${COMPARE}"
  [ "$status" -eq 0 ]
}

@test "script uses get_target_dir from lib.sh" {
  run grep 'get_target_dir' "${COMPARE}"
  [ "$status" -eq 0 ]
}

@test "script sources lib.sh" {
  run grep 'source.*lib.sh' "${COMPARE}"
  [ "$status" -eq 0 ]
}
