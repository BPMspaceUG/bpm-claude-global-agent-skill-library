# Skill S12 – Release & Ops (CI/CD, Versioning & Rollback) Standard

## Goal

Establish a process for releasing software in a controlled manner, including versioning, continuous integration and deployment, artefact packaging and rollback procedures.

## When to Use

- Before cutting a new release of a tool or application.
- When setting up CI/CD pipelines.
- When building an operations playbook for deployments.

## Checklist

- [ ] Follow semantic versioning (`MAJOR.MINOR.PATCH`) for releases.
- [ ] Maintain a `CHANGELOG.md` documenting changes in each release.
- [ ] Tag releases in version control and attach release artefacts (zips, tarballs).
- [ ] Configure a CI pipeline (e.g. GitHub Actions) to run tests on every push and build release artefacts on tags.
- [ ] Publish artefacts to a package registry or release page.
- [ ] Include the install/update script in the release for easy distribution.
- [ ] Define rollback procedures in case of deployment failures:
    - how to revert to the previous version,
    - how to restore data backups,
    - how to notify stakeholders.
- [ ] Monitor deployments with health checks and alerting.
- [ ] Document the release process step by step and automate where possible.

## Minimal Snippets

```
# Example GitHub Actions workflow (simplified)
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

- Releases are repeatable and documented.
- CI/CD runs automatically and reports status.
- Artefacts are available for download and installation.
- Clear rollback steps exist and have been tested.

## Common Failure Modes

- Inconsistent version numbers across code and package metadata.
- Lack of changelog or release notes.
- Manual deployments without automation, leading to human error.
- No rollback plan, causing extended downtime if a release fails.