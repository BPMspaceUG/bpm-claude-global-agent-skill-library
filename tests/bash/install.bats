#!/usr/bin/env bats
#
# install.bats - Tests for install script
# Run with: bats tests/bash/install.bats
#
# Safety:
# - All tests use isolated temp directories (setup/teardown)
# - No real sudo or system changes are made
# - Tests verify script structure and logic, not actual installation

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
INSTALL="${REPO_ROOT}/install"

# ============================================================================
# Setup / Teardown
# ============================================================================

setup() {
  TEST_DIR="$(mktemp -d)"
  # Copy install and lib.sh so source works
  cp "${INSTALL}" "${TEST_DIR}/install"
  cp "${REPO_ROOT}/lib.sh" "${TEST_DIR}/lib.sh"
  chmod +x "${TEST_DIR}/install"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

# ============================================================================
# Tests
# ============================================================================

@test "bash -n syntax check passes" {
  run bash -n "${TEST_DIR}/install"
  [ "$status" -eq 0 ]
}

@test "install script sources lib.sh when available" {
  run grep 'source.*lib.sh' "${INSTALL}"
  [ "$status" -eq 0 ]
}

@test "install script has fallback when lib.sh missing" {
  run grep -A2 'Fallback for piped install' "${INSTALL}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BCGASL_URL="* ]]
}

@test "--with-c-bpm-library block copies lib.sh in local branch" {
  run grep 'sudo cp.*lib.sh.*GLOBAL_BIN/lib.sh' "${INSTALL}"
  [ "$status" -eq 0 ]
}

@test "--with-c-bpm-library block downloads lib.sh in remote branch" {
  run grep 'MY_LIB_URL=.*lib.sh' "${INSTALL}"
  [ "$status" -eq 0 ]
  run grep 'curl.*MY_LIB_URL.*lib.sh' "${INSTALL}"
  [ "$status" -eq 0 ]
}

@test "lib.sh gets chown root:root" {
  run grep 'chown root:root.*lib.sh' "${INSTALL}"
  [ "$status" -eq 0 ]
}

@test "lib.sh gets chmod +x" {
  run grep 'chmod +x.*lib.sh' "${INSTALL}"
  [ "$status" -eq 0 ]
}

@test "c-bpm-cm-library-compare conditionally copied in local branch" {
  # Should check if file exists before copying
  run grep 'if.*-f.*c-bpm-cm-library-compare' "${INSTALL}"
  [ "$status" -eq 0 ]
}

@test "c-bpm-cm-library-compare chown/chmod is conditional" {
  # chown/chmod for compare should be inside an if block
  run grep -A2 'if.*-f.*GLOBAL_BIN/c-bpm-cm-library-compare' "${INSTALL}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chown"* ]]
}

@test "all URLs use HTTPS" {
  # Extract all URLs from the install script
  local http_urls
  http_urls=$(grep -oP 'http://[^\s"]+' "${INSTALL}" || true)
  [ -z "$http_urls" ]
}

@test "all URLs are validated before use" {
  # Every MY_*_URL should have a validate_url call
  local url_vars
  url_vars=$(grep -oP 'MY_\w+_URL=' "${INSTALL}" | sed 's/=//' | sort -u)
  for var in $url_vars; do
    run grep "validate_url.*\$$var" "${INSTALL}"
    [ "$status" -eq 0 ]
  done
}

@test "usage output mentions c-bpm-cm-library-compare" {
  run grep 'c-bpm-cm-library-compare' "${INSTALL}"
  [ "$status" -eq 0 ]
}
