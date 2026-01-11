# Security Hardening Runbook

This runbook aggregates key security practices to harden your applications and infrastructure.

## Access Control

- Use role‑based access control (RBAC) for users and services.
- Regularly review and remove unused accounts and permissions.
- Use multi‑factor authentication for privileged accounts.

## Secrets Management

- Store secrets in a secure vault or environment variables; never in source control.
- Rotate credentials regularly.
- Use the Config & Secrets Standard to load secrets safely.

## File Handling

- Validate and sanitize all file names and paths.
- Check archives for zip‑slip vulnerabilities.
- Store uploads outside of publicly accessible directories and scan them.

## Network and TLS

- Use firewalls or security groups to restrict network access.
- Enforce TLS for all services; disable TLS versions <1.2.
- Apply the TLS & HTTP Headers Standard to web servers.
- Monitor certificate expiration and renew automatically.

## Application Security

- Follow the AppSec & Threat Lite Standard for threat modelling and code review.
- Keep dependencies up to date and run security scans regularly.
- Enable logging and monitoring for authentication events and errors.
- Handle errors gracefully; avoid leaking stack traces or sensitive information.

## Incident Response

- Define an incident response process including detection, triage, containment and remediation.
- Maintain a contact list for security incidents.
- Conduct post‑mortems and update policies based on lessons learned.

## References

- Skill S04 – Config & Secrets Standard
- Skill S10a – AppSec & Threat Lite Standard
- Skill S10b – TLS & HTTP Headers Standard