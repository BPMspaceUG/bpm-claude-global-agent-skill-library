---
name: my-release-ops
description: Process for controlled software releases including versioning, CI/CD, artefact packaging, and rollback procedures. Use before cutting releases, setting up CI/CD, or building deployment playbooks. Derived from S12.
---

# Release & Ops (CI/CD, Versioning & Rollback)

Controlled process for releasing software including versioning, CI/CD, artefact packaging and rollback procedures.

## Checklist

- [ ] Semantic versioning (`MAJOR.MINOR.PATCH`)
- [ ] `CHANGELOG.md` documenting changes per release
- [ ] Tag releases in VCS with attached artefacts (zips, tarballs)
- [ ] CI pipeline (GitHub Actions): tests on every push, artefacts on tags
- [ ] Publish artefacts to registry or release page
- [ ] Include install/update script in release
- [ ] Rollback procedures: revert version, restore data, notify stakeholders
- [ ] Health checks and alerting for deployments
- [ ] Document release process, automate where possible

## Snippets

```yaml
# GitHub Actions (simplified)
on:
  push:
    tags:
      - 'v*.*.*'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: ./scripts/test.sh
      - name: Build artefact
        run: zip -r release.zip .
      - name: Upload release artefact
        uses: actions/upload-artifact@v3
        with:
          name: release
          path: release.zip
```

## Success Criteria

- Releases are repeatable and documented
- CI/CD runs automatically and reports status
- Artefacts available for download and installation
- Rollback steps exist and have been tested

## Common Failure Modes

- Inconsistent version numbers across code and metadata
- Missing changelog or release notes
- Manual deployments leading to human error
- No rollback plan causing extended downtime
