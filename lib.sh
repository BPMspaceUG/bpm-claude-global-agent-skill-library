#!/usr/bin/env bash
#
# lib.sh - Shared functions for bcgasl scripts
#
# Source this file in scripts:
#   source "$(dirname "$0")/lib.sh"
#
# Requires: VERBOSE variable to be set (0 or 1) before calling log_verbose

# Current version
BCGASL_VERSION="1.0.1"

# Trusted domains for downloads (security: only allow known hosts)
TRUSTED_DOMAINS=("github.com" "raw.githubusercontent.com")

# Repository URLs (exported for use by sourcing scripts)
# shellcheck disable=SC2034
REPO_TARBALL="https://github.com/BPMspaceUG/bpm-claude-global-agent-skill-library/archive/refs/tags/v${BCGASL_VERSION}.tar.gz"
# shellcheck disable=SC2034
N8N_TARBALL="https://github.com/czlonkowski/n8n-skills/archive/main.tar.gz"
# shellcheck disable=SC2034
BCGASL_URL="https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/v${BCGASL_VERSION}/bcgasl"

# Checksums file URL
# shellcheck disable=SC2034
CHECKSUMS_URL="https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/checksums.sha256"

# Expected checksum for current version tarball (will be updated in next release)
# shellcheck disable=SC2034
REPO_TARBALL_CHECKSUM="PLACEHOLDER_WILL_BE_UPDATED_IN_NEXT_RELEASE"

# Extracted directory name for the tarball
# shellcheck disable=SC2034
EXTRACTED_DIR_NAME="bpm-claude-global-agent-skill-library-${BCGASL_VERSION}"

# Security: Validate URL against trusted domains
# Usage: validate_url "https://example.com/file"
# Returns: 0 if valid, 1 if invalid
validate_url() {
  local url="$1"
  local host

  # Validate URL is not empty
  if [[ -z "$url" ]]; then
    echo "ERROR: Empty URL provided" >&2
    return 1
  fi

  # Require HTTPS
  if [[ ! "$url" =~ ^https:// ]]; then
    echo "ERROR: URL must use HTTPS: $url" >&2
    return 1
  fi

  # Extract host from URL
  if [[ "$url" =~ ^https://([^/]+)/ ]]; then
    host="${BASH_REMATCH[1]}"
  else
    echo "ERROR: Invalid URL format: $url" >&2
    return 1
  fi

  # Check if host is in trusted domains
  for domain in "${TRUSTED_DOMAINS[@]}"; do
    if [[ "$host" == "$domain" ]]; then
      return 0
    fi
  done

  echo "ERROR: Untrusted domain '$host' in URL: $url" >&2
  echo "Trusted domains: ${TRUSTED_DOMAINS[*]}" >&2
  return 1
}

# Security: Validate path to prevent directory traversal
# Usage: validated_path=$(validate_path "/some/path")
# Returns: validated path or exits with error
# Note: This validates but does not sanitize - it rejects unsafe paths
validate_path() {
  local path="$1"

  # Check for empty path
  if [[ -z "$path" ]]; then
    echo "ERROR: Empty path provided" >&2
    return 1
  fi

  # Reject directory traversal attempts
  if [[ "$path" == *".."* ]]; then
    echo "ERROR: Path contains '..' (directory traversal): $path" >&2
    return 1
  fi

  # Check for null bytes (common injection technique)
  if [[ "$path" == *$'\0'* ]]; then
    echo "ERROR: Path contains null bytes: $path" >&2
    return 1
  fi

  echo "$path"
}

# Alias for backward compatibility
sanitize_path() {
  validate_path "$@"
}

# Security: Validate filename to prevent injection
# Usage: validated=$(validate_filename "myfile.txt")
# Returns: validated filename or exits with error
# Note: This validates but does not sanitize - it rejects unsafe filenames
validate_filename() {
  local filename="$1"

  # Check for empty filename
  if [[ -z "$filename" ]]; then
    echo "ERROR: Empty filename provided" >&2
    return 1
  fi

  # Reject if contains path separators
  if [[ "$filename" == *"/"* ]] || [[ "$filename" == *"\\"* ]]; then
    echo "ERROR: Filename contains path separator: $filename" >&2
    return 1
  fi

  # Reject directory traversal
  if [[ "$filename" == ".." ]] || [[ "$filename" == "." ]]; then
    echo "ERROR: Invalid filename: $filename" >&2
    return 1
  fi

  # Reject filenames starting with dash (could be interpreted as options)
  if [[ "$filename" == -* ]]; then
    echo "ERROR: Filename cannot start with dash: $filename" >&2
    return 1
  fi

  echo "$filename"
}

# Alias for backward compatibility
sanitize_filename() {
  validate_filename "$@"
}

# Verbose logging helper
# Usage: log_verbose "message"
# Requires: VERBOSE variable to be set (0 or 1)
log_verbose() {
  if [[ "${VERBOSE:-0}" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Compute SHA256 checksum of a file
# Usage: checksum=$(compute_sha256 "/path/to/file")
compute_sha256() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found for checksum: $file" >&2
    return 1
  fi

  # Use sha256sum (Linux) or shasum (macOS)
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    echo "ERROR: No sha256sum or shasum command found" >&2
    return 1
  fi
}

# Verify file checksum against expected value
# Usage: verify_checksum "/path/to/file" "expected_sha256"
# Returns: 0 if match, 1 if mismatch
verify_checksum() {
  local file="$1"
  local expected="$2"

  local actual
  actual=$(compute_sha256 "$file") || return 1

  if [[ "$actual" == "$expected" ]]; then
    log_verbose "Checksum verified: $file"
    return 0
  else
    echo "ERROR: Checksum mismatch for $file" >&2
    echo "  Expected: $expected" >&2
    echo "  Actual:   $actual" >&2
    return 1
  fi
}

# Download and verify a file with optional checksum
# Usage: download_with_checksum "url" "/path/to/output" ["expected_sha256"]
# Returns: 0 on success, 1 on failure
download_with_checksum() {
  local url="$1"
  local output="$2"
  local expected_checksum="${3:-}"

  # Validate URL
  validate_url "$url" || return 1

  # Download
  log_verbose "Downloading: $url"
  if ! curl -fsSL "$url" -o "$output"; then
    echo "ERROR: Failed to download: $url" >&2
    return 1
  fi

  # Verify file exists and is not empty
  if [[ ! -s "$output" ]]; then
    echo "ERROR: Downloaded file is empty: $output" >&2
    rm -f "$output"
    return 1
  fi

  # Verify checksum if provided
  if [[ -n "$expected_checksum" ]]; then
    if ! verify_checksum "$output" "$expected_checksum"; then
      rm -f "$output"
      return 1
    fi
  fi

  return 0
}

# Load checksums from a checksums file
# Usage: load_checksums "/path/to/checksums.sha256"
# Sets: LOADED_CHECKSUMS associative array (filename -> checksum)
declare -A LOADED_CHECKSUMS
load_checksums() {
  local checksums_file="$1"
  LOADED_CHECKSUMS=()

  if [[ ! -f "$checksums_file" ]]; then
    log_verbose "No checksums file found: $checksums_file"
    return 0
  fi

  while IFS=' ' read -r checksum filename; do
    # Skip empty lines and comments
    [[ -z "$checksum" || "$checksum" == "#"* ]] && continue
    # Remove leading ./ or * from filename (sha256sum formats vary)
    filename="${filename#./}"
    filename="${filename#\*}"
    LOADED_CHECKSUMS["$filename"]="$checksum"
    log_verbose "Loaded checksum for $filename: $checksum"
  done < "$checksums_file"

  log_verbose "Loaded ${#LOADED_CHECKSUMS[@]} checksums"
  return 0
}

# Get checksum for a file from loaded checksums
# Usage: checksum=$(get_loaded_checksum "filename")
# Returns: checksum or empty string if not found
get_loaded_checksum() {
  local filename="$1"
  echo "${LOADED_CHECKSUMS[$filename]:-}"
}

# Determine the target directory for Claude configuration
# Usage: target=$(get_target_dir)
get_target_dir() {
  if [[ -d "$HOME/.config/claude" ]]; then
    echo "$HOME/.config/claude"
  else
    echo "$HOME/.claude"
  fi
}

# Create a secure temporary directory
# Usage: tmp_dir=$(create_secure_tmpdir)
# Caller is responsible for cleanup: trap 'rm -rf "$tmp_dir"' EXIT
create_secure_tmpdir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)" || {
    echo "ERROR: Failed to create temporary directory" >&2
    return 1
  }

  # Ensure only owner can access
  chmod 700 "$tmp_dir" || {
    rm -rf "$tmp_dir"
    echo "ERROR: Failed to set permissions on temporary directory" >&2
    return 1
  }

  echo "$tmp_dir"
}

# Download file with validation
# Usage: download_file "https://url" "/path/to/output"
# Returns: 0 on success, 1 on failure
download_file() {
  local url="$1"
  local output="$2"

  # Validate URL
  validate_url "$url" || return 1

  # Download with curl
  log_verbose "Downloading: $url -> $output"
  if ! curl -fsSL "$url" -o "$output"; then
    echo "ERROR: Failed to download: $url" >&2
    return 1
  fi

  # Verify file was created and is not empty
  if [[ ! -s "$output" ]]; then
    echo "ERROR: Downloaded file is empty: $output" >&2
    rm -f "$output"
    return 1
  fi

  return 0
}

# Download and extract tarball with validation
# Usage: download_and_extract "https://url" "/path/to/tmpdir" "expected-dir-name"
# Returns: 0 on success, 1 on failure
download_and_extract() {
  local url="$1"
  local tmp_dir="$2"
  local expected_dir="$3"

  # Validate URL
  validate_url "$url" || return 1

  # Download and extract
  log_verbose "Downloading and extracting: $url"
  if ! curl -fsSL "$url" | tar -xz -C "$tmp_dir"; then
    echo "ERROR: Failed to download or extract: $url" >&2
    return 1
  fi

  # Validate extracted directory exists
  if [[ ! -d "$tmp_dir/$expected_dir" ]]; then
    echo "ERROR: Expected directory not found after extraction: $expected_dir" >&2
    return 1
  fi

  log_verbose "Extracted to: $tmp_dir/$expected_dir"
  return 0
}

# Validate directory name is in allowed list
# Usage: validate_dir_name "agents" agents skills runbooks templates
# Returns: 0 if valid, 1 if invalid
validate_dir_name() {
  local dir="$1"
  shift
  local allowed=("$@")

  # Check for empty
  if [[ -z "$dir" ]]; then
    echo "ERROR: Empty directory name" >&2
    return 1
  fi

  # Check against allowed list
  for allowed_dir in "${allowed[@]}"; do
    if [[ "$dir" == "$allowed_dir" ]]; then
      return 0
    fi
  done

  echo "ERROR: Directory '$dir' not in allowed list: ${allowed[*]}" >&2
  return 1
}

# Validate extracted tarball directory name matches expected pattern
# Usage: validate_extracted_dir "repo-name-main" "repo-name"
# Returns: 0 if valid, 1 if invalid
validate_extracted_dir() {
  local actual="$1"
  local expected_prefix="$2"

  # Check for directory traversal or absolute paths
  if [[ "$actual" == *".."* ]] || [[ "$actual" == /* ]]; then
    echo "ERROR: Invalid extracted directory name: $actual" >&2
    return 1
  fi

  # Check it starts with expected prefix
  if [[ ! "$actual" =~ ^${expected_prefix} ]]; then
    echo "ERROR: Extracted directory '$actual' does not match expected pattern '$expected_prefix*'" >&2
    return 1
  fi

  return 0
}

# Check if a command exists
# Usage: command_exists "curl"
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure required commands are available
# Usage: require_commands "curl" "tar" "diff"
require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command_exists "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Required commands not found: ${missing[*]}" >&2
    return 1
  fi
  return 0
}
