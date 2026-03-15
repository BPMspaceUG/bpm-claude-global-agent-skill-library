# Relevance Scoring Patterns

## High Value (0.4 points each)

| Pattern | Tag |
|---------|-----|
| ISO/IEC 42001, ISO 42001 | iso-42001 |
| ISO 27001 | iso-27001 |
| ISO 27701 | iso-27701 |
| NIS2 / NIS-2 | nis2 |
| DORA regulation | dora |
| GDPR / DSGVO | gdpr |
| AI Management System / AIMS | aims |
| Personal?a? certification | personal-certification |
| Auditor certification | auditor-certification |
| Certification body/scheme/program | certification-body |
| Accreditation | accreditation |
| Compliance officer/manager/training | compliance-training |
| CISO | ciso |
| ISMS | isms |

## Medium Value (0.2 points each)

| Pattern | Tag |
|---------|-----|
| certification (general) | certification |
| cybersecurity training/course/bootcamp | cyber-training |
| security awareness | security-awareness |
| risk management/assessment | risk-management |
| audit(ing) | auditing |
| compliance (general) | compliance |
| AI governance/ethics/regulation/act | ai-governance |
| EU AI Act | eu-ai-act |
| CompTIA, CISSP, CISM, CISA | vendor-cert |
| penetration testing | pentest |
| SOC 2 | soc2 |
| BCM / business continuity | bcm |

## Scoring Rules

- Score = sum of matched pattern weights, capped at 1.0
- Category bonus: +0.05 for `security_compliance` subreddits
- Threshold: score >= 0.2 sends post to agent classification
- Tags: deduplicated array of all matched pattern keys
