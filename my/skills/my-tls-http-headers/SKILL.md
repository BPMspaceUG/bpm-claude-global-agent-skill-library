---
name: my-tls-http-headers
description: Baseline for TLS and HTTP security header configuration protecting against downgrade attacks, XSS, and clickjacking. Use when deploying web applications or configuring reverse proxies. Derived from S10b.
---

# TLS & HTTP Headers

Baseline for configuring TLS and HTTP security headers to protect web applications against common attack vectors.

## Checklist

- [ ] TLS 1.2+ with weak ciphers disabled
- [ ] Certificates from trusted CA (e.g. Let's Encrypt) with automatic renewal
- [ ] HSTS with appropriate max-age and includeSubDomains
- [ ] Content Security Policy (CSP) whitelisting trusted sources
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY` or `SAMEORIGIN`
- [ ] `Referrer-Policy` header
- [ ] `Permissions-Policy` header limiting browser features
- [ ] CORS policies configured; avoid wildcard `*`
- [ ] Test with Mozilla Observatory or SSL Labs

## Snippets

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' cdn.example.com";
add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options DENY;
add_header Referrer-Policy no-referrer;
add_header Permissions-Policy "geolocation=(), microphone=()";
```

## Success Criteria

- A rating on SSL/TLS tests
- Security headers present with sensible values
- Browsers enforce secure connections
- Certificates renew automatically

## Common Failure Modes

- Default TLS settings with insecure ciphers
- Overly permissive or missing CSP
- Failing to renew certificates
- Wildcard CORS without restrictions
