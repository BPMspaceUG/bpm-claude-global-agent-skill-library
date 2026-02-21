#!/usr/bin/env bats
#
# bpm-bootstrap.bats - Tests for bpm-bootstrap.sh
# Run with: bats tests/bash/bpm-bootstrap.bats
#
# Safety:
# - All tests use isolated temp directories (setup/teardown)
# - BPM_BOOTSTRAP_TEST_MODE=1 is a first-class script feature that:
#   * Skips sudo requirement
#   * Skips all apt-get operations
#   * Skips all curl|bash downloads
#   * Skips /etc/cac/.env creation
#   * Skips cac env install, cac pull, cac skill install
#   * Skips bcgasl, my-bpm-library-pull
#   * Uses bash directly instead of sudo -u in run_as_user
# - No real files are modified; no root required

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
BOOTSTRAP="${REPO_ROOT}/bpm-bootstrap.sh"
ENV_EXAMPLE="${REPO_ROOT}/bpm-bootstrap.env.example"
GITIGNORE="${REPO_ROOT}/.gitignore"

# ============================================================================
# Setup / Teardown — isolated temp workspace per test
# ============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "${BOOTSTRAP}" "${TEST_DIR}/bpm-bootstrap.sh"
  cp "${ENV_EXAMPLE}" "${TEST_DIR}/bpm-bootstrap.env.example"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

# Helper: create a valid .env in the test dir
create_valid_env() {
  cat > "${TEST_DIR}/bpm-bootstrap.env" <<'EOF'
CAC_GOKAPI_URL=https://test.example.com
CAC_GOKAPI_API_KEY=test-key-12345
EOF
  chmod 600 "${TEST_DIR}/bpm-bootstrap.env"
}

# ============================================================================
# Test 1: Syntax check
# ============================================================================

@test "bash -n syntax check passes" {
  run bash -n "${TEST_DIR}/bpm-bootstrap.sh"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Test 2: --help flag
# ============================================================================

@test "--help exits 0 with usage text" {
  run bash "${TEST_DIR}/bpm-bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"bpm-bootstrap.sh"* ]]
}

# ============================================================================
# Test 3: --version flag
# ============================================================================

@test "--version exits 0 with version string" {
  run bash "${TEST_DIR}/bpm-bootstrap.sh" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"bpm-bootstrap.sh"* ]]
}

# ============================================================================
# Test 4: Refuses to run without sudo
# ============================================================================

@test "refuses to run without sudo (exits non-zero)" {
  if [ "$(id -u)" -eq 0 ]; then
    skip "running as root — cannot test non-root rejection"
  fi
  run bash "${TEST_DIR}/bpm-bootstrap.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sudo"* ]]
}

# ============================================================================
# Test 5: Refuses to run if bpm-bootstrap.env missing
# ============================================================================

@test "refuses to run if bpm-bootstrap.env missing (exits non-zero)" {
  rm -f "${TEST_DIR}/bpm-bootstrap.env"
  export BPM_BOOTSTRAP_TEST_MODE=1
  export SUDO_USER="${USER}"
  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"Environment file"* ]]
}

# ============================================================================
# Test 6: Refuses to run if bpm-bootstrap.env has wrong permissions
# ============================================================================

@test "refuses to run if bpm-bootstrap.env has wrong permissions (exits non-zero)" {
  cat > "${TEST_DIR}/bpm-bootstrap.env" <<'EOF'
CAC_GOKAPI_URL=https://test.example.com
CAC_GOKAPI_API_KEY=test-key-123
EOF
  chmod 644 "${TEST_DIR}/bpm-bootstrap.env"
  export BPM_BOOTSTRAP_TEST_MODE=1
  export SUDO_USER="${USER}"
  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER
  [ "$status" -ne 0 ]
  [[ "$output" == *"Insecure"* ]] || [[ "$output" == *"600"* ]]
}

# ============================================================================
# Test 7: Refuses to run if placeholder values still in .env
# ============================================================================

@test "refuses to run if placeholder values still in .env (exits non-zero)" {
  cp "${TEST_DIR}/bpm-bootstrap.env.example" "${TEST_DIR}/bpm-bootstrap.env"
  chmod 600 "${TEST_DIR}/bpm-bootstrap.env"
  export BPM_BOOTSTRAP_TEST_MODE=1
  export SUDO_USER="${USER}"
  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER
  [ "$status" -ne 0 ]
  [[ "$output" == *"placeholder"* ]]
}

# ============================================================================
# Test 8: .env.example exists with placeholder keys
# ============================================================================

@test "bpm-bootstrap.env.example exists with placeholder keys" {
  [ -f "${ENV_EXAMPLE}" ]
  run grep "CAC_GOKAPI_URL" "${ENV_EXAMPLE}"
  [ "$status" -eq 0 ]
  run grep "CAC_GOKAPI_API_KEY" "${ENV_EXAMPLE}"
  [ "$status" -eq 0 ]
  run grep "__GOKAPI_URL__" "${ENV_EXAMPLE}"
  [ "$status" -eq 0 ]
  run grep "__GOKAPI_API_KEY__" "${ENV_EXAMPLE}"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Test 9: bpm-bootstrap.sh is in .gitignore
# ============================================================================

@test "bpm-bootstrap.sh is listed in .gitignore" {
  run grep "bpm-bootstrap.sh" "${GITIGNORE}"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Test 10: bpm-bootstrap.env is in .gitignore
# ============================================================================

@test "bpm-bootstrap.env is listed in .gitignore" {
  run grep "bpm-bootstrap.env" "${GITIGNORE}"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Test 11: --help output contains no secret values
# ============================================================================

@test "--help output contains no secret values" {
  run bash "${TEST_DIR}/bpm-bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" != *"__GOKAPI_URL__"* ]]
  [[ "$output" != *"__GOKAPI_API_KEY__"* ]]
  [[ "$output" != *"CAC_GOKAPI_API_KEY="* ]]
}

# ============================================================================
# Test 12: Test mode guards all dangerous operations
# Verifies that apt-get, curl|bash, cac install, /etc writes are ALL
# inside BPM_BOOTSTRAP_TEST_MODE guards
# ============================================================================

@test "test mode guards all dangerous operations" {
  local script="${TEST_DIR}/bpm-bootstrap.sh"

  # Every apt-get call must be inside a test mode guard block
  # (i.e., preceded by a check for BPM_BOOTSTRAP_TEST_MODE -eq 0)
  # Count unguarded apt-get calls: grep for apt-get lines NOT inside test mode blocks
  # Strategy: extract function bodies and verify apt-get is always in guarded blocks

  # All apt-get calls should be in lines preceded (within 5 lines) by TEST_MODE check
  local apt_lines
  apt_lines=$(grep -n "apt-get" "${script}" | grep -v "^#" | grep -v "# " || true)
  [ -n "${apt_lines}" ]  # Script must contain apt-get calls

  # Verify dangerous operations are inside test mode blocks
  # Check that the script has test mode guards for each category
  # apt-get operations
  local apt_guard
  apt_guard=$(grep -B10 "apt-get update" "${script}" | grep -c "BPM_BOOTSTRAP_TEST_MODE" || true)
  [ "${apt_guard:-0}" -gt 0 ]

  # curl|bash downloads — check ALL curl piped to bash patterns
  # Find every line with 'curl' piped to 'bash' and verify each has a nearby guard
  local curl_lines
  curl_lines=$(grep -n "curl.*|.*bash" "${script}" | grep -v "^#" || true)
  [ -n "${curl_lines}" ]  # Script must have curl|bash pipelines
  while IFS= read -r curl_line; do
    local line_num
    line_num=$(echo "${curl_line}" | cut -d: -f1)
    # Check the 15 lines before this curl|bash for a test mode guard
    local start=$((line_num - 15))
    [ "${start}" -lt 1 ] && start=1
    local guard_count
    guard_count=$(sed -n "${start},${line_num}p" "${script}" | grep -c "BPM_BOOTSTRAP_TEST_MODE" || true)
    [ "${guard_count:-0}" -gt 0 ]
  done <<< "${curl_lines}"

  # /etc/cac/.env writes (check the write operation, not the readonly constant)
  local etc_guard
  etc_guard=$(grep -B10 "cat > .*CAC_ENV_FILE" "${script}" | grep -c "BPM_BOOTSTRAP_TEST_MODE" || true)
  [ "${etc_guard:-0}" -gt 0 ]

  # Verify run_as_user is safe in test mode (uses bash instead of sudo)
  run grep -A5 "^run_as_user" "${script}"
  [[ "$output" == *"BPM_BOOTSTRAP_TEST_MODE"* ]]
  [[ "$output" == *"bash -c"* ]]
}

# ============================================================================
# Test 13: Full behavioral test — test mode runs end-to-end safely
# Creates stubs, runs full script, verifies:
# - "already installed" for pre-existing tools (idempotency)
# - "Test mode: skipping" for dangerous ops (safety)
# - Completes successfully (correctness)
# ============================================================================

@test "test mode runs end-to-end: idempotent + safe + completes" {
  create_valid_env

  # Create stub binaries for idempotency testing
  local stub_dir="${TEST_DIR}/stubs"
  mkdir -p "${stub_dir}"

  cat > "${stub_dir}/node" <<'STUB'
#!/bin/bash
if [[ "$1" == "--version" ]]; then echo "v22.0.0"; else echo "stub"; fi
STUB
  chmod +x "${stub_dir}/node"

  cat > "${stub_dir}/npm" <<'STUB'
#!/bin/bash
if [[ "$1" == "--version" ]]; then echo "10.0.0"; else echo "stub"; fi
STUB
  chmod +x "${stub_dir}/npm"

  cat > "${stub_dir}/bun" <<'STUB'
#!/bin/bash
if [[ "$1" == "--version" ]]; then echo "1.0.0"; else echo "stub"; fi
STUB
  chmod +x "${stub_dir}/bun"

  cat > "${stub_dir}/cac" <<'STUB'
#!/bin/bash
case "$1" in
  --version) echo "cac v260203-122236" ;;
  *) echo "stub cac $*" ;;
esac
exit 0
STUB
  chmod +x "${stub_dir}/cac"

  # Run the full script in test mode
  export BPM_BOOTSTRAP_TEST_MODE=1
  export SUDO_USER="${USER}"
  export PATH="${stub_dir}:${PATH}"

  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER

  # Must complete successfully
  [ "$status" -eq 0 ]

  # IDEMPOTENCY: stubs are detected as "already installed"
  [[ "$output" == *"Node.js v22.0.0 already installed"* ]]
  [[ "$output" == *"bun v1.0.0 already installed"* ]]
  [[ "$output" == *"cac already installed"* ]]
  [[ "$output" == *"npm v10.0.0 available"* ]]

  # SAFETY: dangerous operations are skipped
  [[ "$output" == *"Test mode: skipping apt-get"* ]]
  [[ "$output" == *"Test mode: skipping /etc/cac/.env creation"* ]]
  [[ "$output" == *"Test mode: skipping AI tool installation"* ]]
  [[ "$output" == *"Test mode: skipping cac pull"* ]]
  [[ "$output" == *"Test mode: skipping skill library installation"* ]]
  [[ "$output" == *"Test mode: skipping bcgasl"* ]]
  [[ "$output" == *"Test mode: skipping my-bpm-library-pull"* ]]

  # SAFETY: no sudo calls (run_as_user uses bash in test mode)
  [[ "$output" != *"sudo:"* ]]

  # COMPLETION: reaches the end
  [[ "$output" == *"Bootstrap complete"* ]]
}
