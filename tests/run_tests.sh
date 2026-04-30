#!/usr/bin/env bash
# tests/run_tests.sh - run the bats suite under tests/bash/
# Deterministic and offline-friendly: requires bats on PATH.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v bats >/dev/null 2>&1; then
  cat >&2 <<'EOF'
ERROR: bats is required to run the test suite.
Install: apt install bats   (Debian/Ubuntu)
     or: npm install -g bats   (any Node host)
     or: brew install bats-core  (macOS)
After install, re-run ./tests/run_tests.sh
EOF
  exit 2
fi

exec bats tests/bash/
