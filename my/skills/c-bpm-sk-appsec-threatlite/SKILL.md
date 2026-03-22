---
model: opus
name: c-bpm-sk-appsec-threatlite
description: "Security review checklist — threat model, appsec review, vulnerability check, file handling safety, auth review, compliance, remediation tracking. Lightweight security review with structured reporting."
enforcement: block
intentPatterns: "threat model;;security (review|checklist|audit);;appsec review;;vulnerability (check|scan)"
user-invocable: false
---

# AppSec & Threat Lite

Lightweight threat-model and checklist for application security, focusing on file handling safety and minimising common vulnerabilities.

## Checklist

- [ ] Identify assets (data, credentials, endpoints) and threats (unauthorised access, tampering)
- [ ] Validate all inputs; enforce strict types and ranges
- [ ] Sanitize filenames and paths to prevent directory traversal
- [ ] Check archives for zip-slip by verifying extraction paths
- [ ] Avoid sensitive files in publicly accessible directories
- [ ] Limit file uploads by size and type; scan for malware where possible
- [ ] Log security events (login attempts, permission changes) with timestamps
- [ ] Least privilege: scripts and processes run with minimal permissions
- [ ] Dependencies up to date and free from known vulnerabilities
- [ ] Review authentication and authorisation in backends and APIs
- [ ] Review `.env` and configuration files for secrets exposure
- [ ] Verify TLS and HTTP header configuration (see c-bpm-sk-tls-http-headers)
- [ ] Consider compliance requirements (GDPR, PCI) where applicable

## Snippets

```bash
# Zip-slip check
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

- Threats identified and documented before implementation
- File operations protected against traversal and zip-slip
- Least privilege consistently applied
- Security controls included in application design

## Remediation Report

Structure security findings as:

| Field | Content |
|-------|---------|
| Finding | Description of the vulnerability |
| Severity | Critical / High / Medium / Low |
| File/Component | Affected file paths or workflow names |
| Recommended Action | Specific fix with best practice reference |
| Status | Open / In Progress / Resolved |

Track findings to closure — document vulnerabilities, assign to implementers, do not fix silently.

## Common Failure Modes

- Missing or superficial threat assessments
- Extracting archives without verifying file paths
- Running scripts as root when not necessary
- Ignoring dependency vulnerabilities
