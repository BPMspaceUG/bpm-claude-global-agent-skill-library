#!/usr/bin/env bats
#
# bpm-bootstrap.bats - Tests for bpm-bootstrap.sh
# Run with: bats tests/bash/bpm-bootstrap.bats
#
# Safety:
# - All tests use isolated temp directories (setup/teardown)
# - BPM_BOOTSTRAP_TEST_MODE=1 is a first-class script feature that:
#   * Skips sudo requirement
#   * Skips all apt-get, curl|bash, cac operations
#   * Uses bash instead of sudo in run_as_user
# - No real files are modified; no root required

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
BOOTSTRAP="${REPO_ROOT}/bpm-bootstrap.sh"
ENV_EXAMPLE="${REPO_ROOT}/bpm-bootstrap.env.example"
GITIGNORE="${REPO_ROOT}/.gitignore"

# ============================================================================
# Setup / Teardown
# ============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  cp "${BOOTSTRAP}" "${TEST_DIR}/bpm-bootstrap.sh"
  cp "${ENV_EXAMPLE}" "${TEST_DIR}/bpm-bootstrap.env.example"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

create_valid_env() {
  cat > "${TEST_DIR}/bpm-bootstrap.env" <<'EOF'
CAC_GOKAPI_URL=https://test.example.com
CAC_GOKAPI_API_KEY=test-key-12345
EOF
  chmod 600 "${TEST_DIR}/bpm-bootstrap.env"
}

# ============================================================================
# Tests
# ============================================================================

@test "bash -n syntax check passes" {
  run bash -n "${TEST_DIR}/bpm-bootstrap.sh"
  [ "$status" -eq 0 ]
}

@test "--help exits 0 with usage text" {
  run bash "${TEST_DIR}/bpm-bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"bpm-bootstrap.sh"* ]]
  [[ "$output" == *"non-interactive"* ]] || [[ "$output" == *"Non-interactive"* ]]
}

@test "--version exits 0 with version string" {
  run bash "${TEST_DIR}/bpm-bootstrap.sh" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"bpm-bootstrap.sh"* ]]
}

@test "refuses to run without sudo (exits non-zero)" {
  if [ "$(id -u)" -eq 0 ]; then
    skip "running as root"
  fi
  run bash "${TEST_DIR}/bpm-bootstrap.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sudo"* ]]
}

@test "refuses to run if bpm-bootstrap.env missing" {
  rm -f "${TEST_DIR}/bpm-bootstrap.env"
  export BPM_BOOTSTRAP_TEST_MODE=1 SUDO_USER="${USER}"
  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"Environment file"* ]]
}

@test "refuses to run if placeholder values still in .env" {
  cp "${TEST_DIR}/bpm-bootstrap.env.example" "${TEST_DIR}/bpm-bootstrap.env"
  chmod 600 "${TEST_DIR}/bpm-bootstrap.env"
  export BPM_BOOTSTRAP_TEST_MODE=1 SUDO_USER="${USER}"
  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER
  [ "$status" -ne 0 ]
  [[ "$output" == *"placeholder"* ]]
}

@test "auto-fixes .env permissions instead of failing" {
  cat > "${TEST_DIR}/bpm-bootstrap.env" <<'EOF'
CAC_GOKAPI_URL=https://test.example.com
CAC_GOKAPI_API_KEY=test-key-12345
EOF
  chmod 644 "${TEST_DIR}/bpm-bootstrap.env"
  export BPM_BOOTSTRAP_TEST_MODE=1 SUDO_USER="${USER}"
  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER
  # Should succeed (auto-fix) not fail
  [ "$status" -eq 0 ]
  # Should warn about fixing permissions
  [[ "$output" == *"fixing to 600"* ]] || [[ "$output" == *"attempting fix"* ]]
}

@test "chmod failure on FAT filesystem does not abort" {
  # Verify the script handles chmod failure gracefully
  local script="${TEST_DIR}/bpm-bootstrap.sh"
  # The chmod call must have '|| warn' or '2>/dev/null' to survive FAT/exFAT
  run grep "chmod 600.*dotenv" "${script}"
  [[ "$output" == *"|| warn"* ]] || [[ "$output" == *"2>/dev/null"* ]]
}

@test "bpm-bootstrap.env.example has placeholder keys" {
  [ -f "${ENV_EXAMPLE}" ]
  run grep "CAC_GOKAPI_URL=__GOKAPI_URL__" "${ENV_EXAMPLE}"
  [ "$status" -eq 0 ]
  run grep "CAC_GOKAPI_API_KEY=__GOKAPI_API_KEY__" "${ENV_EXAMPLE}"
  [ "$status" -eq 0 ]
}

@test "bpm-bootstrap.env is in .gitignore (script is committed)" {
  run grep "bpm-bootstrap.env" "${GITIGNORE}"
  [ "$status" -eq 0 ]
  # Script itself should NOT be gitignored (no hardcoded secrets)
  run grep "^bpm-bootstrap\.sh$" "${GITIGNORE}"
  [ "$status" -ne 0 ]
}

@test "--help output contains no secret values" {
  run bash "${TEST_DIR}/bpm-bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" != *"__GOKAPI_URL__"* ]]
  [[ "$output" != *"__GOKAPI_API_KEY__"* ]]
  [[ "$output" != *"CAC_GOKAPI_API_KEY="* ]]
}

@test "test mode guards all dangerous operations" {
  local script="${TEST_DIR}/bpm-bootstrap.sh"

  # apt-get guarded
  local apt_guard
  apt_guard=$(grep -B10 "apt-get" "${script}" | grep -c "BPM_BOOTSTRAP_TEST_MODE" || true)
  [ "${apt_guard:-0}" -gt 0 ]

  # ALL curl|bash pipelines guarded
  local curl_lines
  curl_lines=$(grep -n "curl.*|.*bash" "${script}" | grep -v "^#" || true)
  [ -n "${curl_lines}" ]
  while IFS= read -r curl_line; do
    local line_num
    line_num=$(echo "${curl_line}" | cut -d: -f1)
    local start=$((line_num - 15))
    [ "${start}" -lt 1 ] && start=1
    local guard_count
    guard_count=$(sed -n "${start},${line_num}p" "${script}" | grep -c "BPM_BOOTSTRAP_TEST_MODE" || true)
    [ "${guard_count:-0}" -gt 0 ]
  done <<< "${curl_lines}"

  # /etc/cac write guarded
  local etc_guard
  etc_guard=$(grep -B10 "cat > .*CAC_ENV_FILE" "${script}" | grep -c "BPM_BOOTSTRAP_TEST_MODE" || true)
  [ "${etc_guard:-0}" -gt 0 ]

  # run_as_user skips sudo in test mode
  run grep -A5 "^run_as_user" "${script}"
  [[ "$output" == *"BPM_BOOTSTRAP_TEST_MODE"* ]]
  [[ "$output" == *"bash -c"* ]]
}

@test "test mode runs end-to-end: idempotent + safe + completes" {
  create_valid_env

  local stub_dir="${TEST_DIR}/stubs"
  mkdir -p "${stub_dir}"

  cat > "${stub_dir}/curl" <<'STUB'
#!/bin/bash
echo "stub curl"
STUB
  chmod +x "${stub_dir}/curl"

  cat > "${stub_dir}/cac" <<'STUB'
#!/bin/bash
case "$1" in
  --version) echo "cac v260203-122236" ;;
  *) echo "stub cac $*" ;;
esac
exit 0
STUB
  chmod +x "${stub_dir}/cac"

  export BPM_BOOTSTRAP_TEST_MODE=1 SUDO_USER="${USER}"
  export PATH="${stub_dir}:${PATH}"

  run env EUID=0 bash "${TEST_DIR}/bpm-bootstrap.sh"
  unset BPM_BOOTSTRAP_TEST_MODE SUDO_USER

  [ "$status" -eq 0 ]

  # Idempotency: curl and cac detected as already installed
  [[ "$output" == *"curl already available"* ]]
  [[ "$output" == *"cac already installed"* ]]

  # Safety: dangerous ops skipped
  [[ "$output" == *"Test mode: skipping"* ]]
  [[ "$output" != *"sudo:"* ]]

  # Completes
  [[ "$output" == *"Bootstrap complete"* ]]
}

@test "script has exactly 6 steps" {
  local script="${TEST_DIR}/bpm-bootstrap.sh"
  local step_count
  # Count step_header calls (not the function definition)
  step_count=$(grep -c 'step_header [0-9]' "${script}" || true)
  [ "${step_count}" -eq 6 ]
}
