# Release

`__APP_NAME__` is distributed outside the Mac App Store with Developer ID signing, Hardened Runtime, Apple notarization, and GitHub Releases.

## Prepare

Merge the intended bug-fix and feature PRs first. Keep version bumps, build-number changes, and `.github/release-notes.md` out of those PRs, including separate release commits within them.

Prepare a release when Clyde explicitly requests one, rather than bumping the version for each PR. A release can include multiple merged PRs. For a user-facing release, set a new `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION`; for a build-only release, increment only `CURRENT_PROJECT_VERSION`. Update `.github/release-notes.md` with the changes being released and put the release preparation in one dedicated `chore: release vX.Y.Z` commit.

A Release PR is not required by default. With explicit approval, push the standalone release commit directly to `main`. Use a separate release-only PR when branch protection requires it or Clyde requests one. The release commit must be on `main` before tagging.

## Prerequisites

- The Release configuration has the intended entitlements and Hardened Runtime enabled.
- `MARKETING_VERSION` contains the user-facing version.
- `CURRENT_PROJECT_VERSION` contains a globally increasing build number.
- `.github/release-notes.md` describes the user-visible changes.
- The repository release variable and secrets are configured.
- The release commit is on `main` and ready to tag.

## Publish

After explicit approval to tag and publish, create and push a tag that exactly matches the Xcode versions:

```bash
git tag vX.Y.Z-build.N
git push origin vX.Y.Z-build.N
```

The workflow rejects tags that do not match `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, and publishes nothing if the tag's tests fail. A successful run archives `__SCHEME__`, signs `__APP_NAME__.app` with Developer ID, submits it to Apple's notary service, staples the ticket, validates it with Gatekeeper, and uploads the notarized ZIP plus a SHA-256 checksum.

## Retry

Use the Release workflow's manual dispatch with the existing tag. Re-running an accepted release replaces the assets and refreshes the title and repository-managed release notes.
