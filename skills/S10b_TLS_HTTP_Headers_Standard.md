# Skill S10b – TLS & HTTP Headers Standard

## Goal

Define a baseline for configuring TLS and HTTP security headers to protect web applications against common attack vectors such as downgrade attacks, cross‑site scripting and clickjacking.

## When to Use

- When deploying web applications or APIs.
- When configuring reverse proxies (e.g. Nginx, Caddy) or web servers.

## Checklist

- [ ] Use strong TLS versions (TLS 1.2 or higher) and disable weak ciphers.
- [ ] Obtain certificates from a trusted CA (e.g. Let's Encrypt) and configure automatic renewal.
- [ ] Enable HTTP Strict Transport Security (HSTS) with an appropriate max‑age and includeSubDomains where safe.
- [ ] Set a Content Security Policy (CSP) that whitelists trusted sources for scripts, styles and other resources.
- [ ] Add a `X‑Content‑Type‑Options: nosniff` header to prevent MIME type sniffing.
- [ ] Add a `X‑Frame‑Options: DENY` or `SAMEORIGIN` header to prevent clickjacking.
- [ ] Add a `Referrer‑Policy` header to restrict how much referrer information is sent.
- [ ] Add a `Permissions‑Policy` header to limit access to browser features.
- [ ] Configure CORS policies appropriately; avoid wildcard `*` unless strictly necessary.
- [ ] Test the configuration using tools like Mozilla Observatory or SSL Labs.

## Minimal Snippets

```
# Example Nginx snippet
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

- Web servers receive an A rating on SSL/TLS tests.
- Security headers are present and configured with sensible values.
- Browsers enforce secure connections and restrict malicious content sources.
- Certificates renew automatically without downtime.

## Common Failure Modes

- Leaving default TLS settings, which may include insecure ciphers.
- Overly permissive CSP or missing CSP entirely.
- Failing to renew certificates in time.
- Allowing all origins in CORS headers without restrictions.