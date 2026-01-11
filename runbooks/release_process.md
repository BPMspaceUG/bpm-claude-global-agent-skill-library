# Release Process Runbook

This runbook describes the steps required to create and publish a new release of a project using the global Claude agents and skills library.

## Prerequisites

- All code changes have been reviewed and merged into the `main` branch.
- All tests pass on the continuous integration pipeline.
- The `CHANGELOG.md` has been updated with user‑facing changes.

## Steps

1. **Determine the version number**: Choose a new semantic version based on the changes (major, minor or patch).
2. **Create a release branch**:
   ```bash
   git checkout -b release/vX.Y.Z
   ```
3. **Update version files**:
   - Update any `VERSION` or metadata files.
   - Commit the version bump.
4. **Tag the release**:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   ```
5. **Run the test harness**:
   ```bash
   ./scripts/test.sh
   ```
   Ensure all tests pass.
6. **Push the release branch and tags**:
   ```bash
   git push origin release/vX.Y.Z
   git push origin vX.Y.Z
   ```
7. **Let CI build and upload artefacts**: The CI pipeline will build and upload release artefacts automatically.
8. **Draft a GitHub release**:
   - Use the generated artefacts.
   - Copy the relevant section from the `CHANGELOG.md`.
   - Add any additional release notes.
9. **Notify stakeholders**: Send a summary of the release to the team and update documentation where necessary.

## Rollback

If the release causes issues:

- Revert the deployment to the previous stable tag.
- Investigate the cause of the issue and fix it on a new branch.
- Prepare a patch release (increment the patch version) following the same process.

## References

- Skill S12 – Release & Ops (CI/CD, Versioning & Rollback) Standard