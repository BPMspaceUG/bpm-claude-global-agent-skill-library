# Skill S10a – AppSec & Threat Lite Standard

## Goal

Establish a lightweight threat‑model and checklist for application security, focusing on file handling safety and minimising common vulnerabilities.

## When to Use

- During security reviews of scripts, code and workflows.
- When integrating any external input or file handling in the application.

## Checklist

- [ ] Identify assets (data, credentials, endpoints) and potential threats (unauthorised access, tampering).
- [ ] Validate all inputs; enforce strict types and ranges.
- [ ] Sanitize filenames and paths to prevent directory traversal.
- [ ] Check archives (zip/tar) for zip‑slip vulnerabilities by verifying extraction paths.
- [ ] Avoid storing sensitive files in publicly accessible directories.
- [ ] Limit file uploads by size and type; scan for malware where possible.
- [ ] Log security‑relevant events (login attempts, permission changes) with timestamps and user identifiers.
- [ ] Enforce least privilege: scripts and processes should run with minimal permissions necessary.
- [ ] Ensure dependencies are up to date and free from known vulnerabilities.

## Minimal Snippets

```
# Example zip-slip check in Bash
extract_safe() {
  local archive="$1"
  local dest="$2"
  mkdir -p "$dest"
  while read -r file; do
    case "$file" in
      */*) dest_path="$dest/${file}";;
      *) dest_path="$dest/$file";;
    esac
    if [[ "$dest_path" != "$dest"* ]]; then
      echo "Unsafe file detected: $file"; return 1;
    fi
    mkdir -p "$(dirname "$dest_path")"
    unzip -p "$archive" "$file" > "$dest_path"
  done < <(zipinfo -1 "$archive")
}
```

## Success Criteria

- Threats are identified and documented before implementation.
- File operations are protected against traversal and zip‑slip attacks.
- The principle of least privilege is consistently applied.
- Security controls are included in the application design.

## Common Failure Modes

- Missing or superficial threat assessments.
- Extracting archives without verifying file paths.
- Running scripts as root when not necessary.
- Ignoring dependency vulnerabilities.