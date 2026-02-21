#!/usr/bin/env bash
#
# bpm-bootstrap.sh - Non-interactive bootstrap for AI coding agent environment
#
# Run from USB stick after fresh Ubuntu Desktop install.
# The .env file must be in the same directory as this script.
#
# Usage:
#   sudo bash bpm-bootstrap.sh          # Full non-interactive bootstrap
#   bash bpm-bootstrap.sh --help        # Show help
#   bash bpm-bootstrap.sh --version     # Show version
#
# Steps (fully non-interactive, global install):
#   1. Ensure curl is available (apt-get install if missing)
#   2. Install cac (Coding Agent Config)
#   3. Install all 4 AI agents (Claude Code, Codex CLI, Gemini CLI, continuous-claude)
#   4. cac pull (download credentials from Gokapi)
#   5. cac check (verify all credentials work)
#   6. cac skill install BPM + ICO libraries

set -euo pipefail
IFS=$'\n\t'

# Version: YYMMDD-HHMM from HEAD commit
BPM_BOOTSTRAP_VERSION="dev"
_tool_dir="$(dirname "${BASH_SOURCE[0]:-}")"
if git -C "$_tool_dir" rev-parse --git-dir &>/dev/null; then
    BPM_BOOTSTRAP_VERSION=$(git -C "$_tool_dir" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "dev")
    if ! git -C "$_tool_dir" diff --quiet HEAD 2>/dev/null || ! git -C "$_tool_dir" diff --cached --quiet HEAD 2>/dev/null; then
        BPM_BOOTSTRAP_VERSION="${BPM_BOOTSTRAP_VERSION}-dirty"
    elif ! git -C "$_tool_dir" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
        BPM_BOOTSTRAP_VERSION="${BPM_BOOTSTRAP_VERSION}-draft"
    fi
fi
unset _tool_dir

# ============================================================================
# Constants
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly ENV_FILE="${SCRIPT_DIR}/bpm-bootstrap.env"
readonly CAC_ENV_DIR="/etc/cac"
readonly CAC_ENV_FILE="${CAC_ENV_DIR}/.env"
readonly CAC_INSTALL_URL="https://raw.githubusercontent.com/BPMspaceUG/cac/main/install.sh"
readonly BPM_SKILL_REPO="https://github.com/BPMspaceUG/bpm-claude-global-agent-skill-library.git"
readonly ICO_SKILL_REPO="https://github.com/International-Certification-Org/ico-claude-global-agent-skill-library.git"

TMP_DIR=""

# ============================================================================
# Helpers
# ============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

step_header() {
  echo ""
  echo -e "${BLUE}──── Step $1: $2 ────${NC}"
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT INT TERM

run_as_user() {
  local target_user="$1"
  shift
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 1 ]]; then
    bash -c "$*"
  else
    sudo -u "${target_user}" -- bash -c "$*"
  fi
}

show_help() {
  cat <<EOF
bpm-bootstrap.sh v${BPM_BOOTSTRAP_VERSION}

Non-interactive bootstrap for AI coding agent environment.
Run from USB stick after fresh Ubuntu Desktop install.

Usage:
  sudo bash bpm-bootstrap.sh      Full bootstrap (no interaction needed)
  bash bpm-bootstrap.sh --help    Show this help
  bash bpm-bootstrap.sh --version Show version

Requirements:
  - bpm-bootstrap.env in the same directory (with Gokapi credentials)
  - Must be run with sudo
  - Internet connection

Steps:
  1. Ensure curl available
  2. Install cac (global)
  3. Install AI agents: Claude Code, Codex CLI, Gemini CLI, continuous-claude
  4. cac pull (credentials from Gokapi)
  5. cac check (verify credentials)
  6. cac skill install (BPM + ICO libraries)
EOF
}

# ============================================================================
# Dotenv loader (my-bpm-config-secrets skill)
# ============================================================================

load_env() {
  local dotenv_file="$1"

  if [[ ! -f "${dotenv_file}" ]]; then
    err "Environment file not found: ${dotenv_file}"
    err "Expected bpm-bootstrap.env next to this script"
    return 1
  fi

  # Validate permissions — auto-fix to 600 if possible
  # On FAT/exFAT (USB sticks), chmod may fail silently — that's acceptable
  local perms
  perms=$(stat -c '%a' "${dotenv_file}" 2>/dev/null || echo "unknown")
  if [[ "${perms}" != "600" ]] && [[ "${perms}" != "400" ]] && [[ "${perms}" != "700" ]]; then
    warn "Permissions on ${dotenv_file}: ${perms} — attempting fix to 600"
    chmod 600 "${dotenv_file}" 2>/dev/null || warn "chmod failed (FAT/exFAT filesystem?) — continuing"
  fi

  # Disable trace mode before sourcing secrets
  set +x 2>/dev/null || true
  set -a
  # shellcheck source=/dev/null
  source "${dotenv_file}"
  set +a
}

validate_env() {
  local missing=0

  if [[ -z "${CAC_GOKAPI_URL:-}" ]] || [[ "${CAC_GOKAPI_URL:-}" == "__GOKAPI_URL__" ]]; then
    err "CAC_GOKAPI_URL not set or still placeholder in ${ENV_FILE}"
    missing=1
  fi
  if [[ -z "${CAC_GOKAPI_API_KEY:-}" ]] || [[ "${CAC_GOKAPI_API_KEY:-}" == "__GOKAPI_API_KEY__" ]]; then
    err "CAC_GOKAPI_API_KEY not set or still placeholder in ${ENV_FILE}"
    missing=1
  fi

  if [[ "${missing}" -eq 1 ]]; then
    return 1
  fi

  info "CAC_GOKAPI_URL=<set>"
  info "CAC_GOKAPI_API_KEY=<set>"
}

# ============================================================================
# Main
# ============================================================================

main() {
  case "${1:-}" in
    --help|-h)
      show_help
      exit 0
      ;;
    --version|-v)
      echo "bpm-bootstrap.sh ${BPM_BOOTSTRAP_VERSION}"
      exit 0
      ;;
  esac

  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  bpm-bootstrap.sh v${BPM_BOOTSTRAP_VERSION}${NC}"
  echo -e "${BLUE}  Non-interactive AI coding agent bootstrap${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

  TMP_DIR="$(mktemp -d)"

  # --- Pre-flight ---
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]] && [[ "${EUID}" -ne 0 ]]; then
    err "Must run with sudo: sudo bash $0"
    exit 1
  fi

  TARGET_USER="${SUDO_USER:-${USER}}"
  TARGET_HOME="$(eval echo "~${TARGET_USER}")"
  if [[ -z "${TARGET_USER}" ]] || [[ "${TARGET_USER}" == "root" ]]; then
    err "Cannot determine desktop user. Run with: sudo bash $0"
    exit 1
  fi
  info "Target user: ${TARGET_USER}"

  # Load .env from USB stick (same dir as script)
  load_env "${ENV_FILE}"
  validate_env

  # Write /etc/cac/.env
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
    mkdir -p "${CAC_ENV_DIR}"
    cat > "${CAC_ENV_FILE}" <<ENVEOF
CAC_BACKEND=gokapi
CAC_GOKAPI_URL=${CAC_GOKAPI_URL}
CAC_GOKAPI_API_KEY=${CAC_GOKAPI_API_KEY}
CAC_GOKAPI_EXPIRY_DAYS=0
CAC_GOKAPI_ALLOWED_DOWNLOADS=0
ENVEOF
    chown root:root "${CAC_ENV_FILE}"
    chmod 600 "${CAC_ENV_FILE}"
    ok "/etc/cac/.env written"
  else
    info "Test mode: skipping /etc/cac/.env creation"
  fi

  # ── Step 1: Ensure curl ──────────────────────────────────────
  step_header 1 "Ensure curl"
  if command -v curl &>/dev/null; then
    ok "curl already available"
  else
    if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
      info "Installing curl..."
      apt-get update -qq
      apt-get install -y -qq curl > /dev/null
      ok "curl installed"
    else
      warn "Test mode: would install curl"
    fi
  fi

  # ── Step 2: Install cac ─────────────────────────────────────
  step_header 2 "Install cac"
  if command -v cac &>/dev/null; then
    ok "cac already installed: $(cac --version 2>/dev/null || echo 'unknown')"
  else
    if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
      info "Installing cac globally..."
      curl -fsSL "${CAC_INSTALL_URL}" | bash -s -- --global
      ok "cac installed"
    else
      warn "Test mode: would install cac"
    fi
  fi

  if ! command -v cac &>/dev/null; then
    if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
      err "cac not found after installation — aborting"
      exit 1
    else
      warn "Test mode: cac not available"
      ok "Test mode: steps 3-6 skipped"
      return 0
    fi
  fi

  # ── Step 3: Install all 4 AI agents ─────────────────────────
  step_header 3 "Install AI agents"
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
    info "Installing Claude Code (global)..."
    cac env install claude --global --yes || warn "Claude Code install failed"

    info "Installing Codex CLI (global)..."
    cac env install codex --global --yes || warn "Codex CLI install failed"

    info "Installing Gemini CLI (global)..."
    cac env install gemini --global --yes || warn "Gemini CLI install failed"

    info "Installing continuous-claude (global)..."
    cac env install continuous-claude --global --yes || warn "continuous-claude failed (optional)"
    ok "AI agents installed"
  else
    info "Test mode: skipping AI agent installation"
  fi

  # ── Step 4: cac pull ────────────────────────────────────────
  step_header 4 "Pull credentials (cac pull)"
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
    run_as_user "${TARGET_USER}" "cac pull" || warn "cac pull failed"
    ok "Credentials pulled"
  else
    info "Test mode: skipping cac pull"
  fi

  # ── Step 5: cac check ───────────────────────────────────────
  step_header 5 "Verify credentials (cac check)"
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
    run_as_user "${TARGET_USER}" "cac check" || warn "Some credential checks failed"
    ok "Credential verification done"
  else
    info "Test mode: skipping cac check"
  fi

  # ── Step 6: Install skill libraries ─────────────────────────
  step_header 6 "Install skill libraries (BPM + ICO)"
  if [[ "${BPM_BOOTSTRAP_TEST_MODE:-0}" -eq 0 ]]; then
    info "Installing BPM skill library..."
    run_as_user "${TARGET_USER}" "cac skill install ${BPM_SKILL_REPO} --yes" \
      || warn "BPM skill library install failed"

    info "Installing ICO skill library..."
    run_as_user "${TARGET_USER}" "cac skill install ${ICO_SKILL_REPO} --yes" \
      || warn "ICO skill library install failed"

    ok "Skill libraries installed"
  else
    info "Test mode: skipping skill library installation"
  fi

  # ── Summary ─────────────────────────────────────────────────
  echo ""
  echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Bootstrap complete! (v${BPM_BOOTSTRAP_VERSION})${NC}"
  echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  User: ${TARGET_USER}"
  echo ""
  command -v cac     &>/dev/null && echo "  cac       $(cac --version 2>/dev/null || echo 'installed')"
  command -v claude  &>/dev/null && echo "  claude    $(claude --version 2>/dev/null || echo 'installed')"
  command -v codex   &>/dev/null && echo "  codex     installed"
  command -v gemini  &>/dev/null && echo "  gemini    installed"
  echo ""
  echo "  Open a new terminal, then run: claude"
  echo ""
}

main "$@"
