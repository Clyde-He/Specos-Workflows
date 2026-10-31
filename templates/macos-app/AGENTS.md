# Agent Instructions

## Working Style

- Discuss diagnosis and options before editing when the user asks a question or reports a symptom.
- Implement changes only after explicit approval.
- Do not push, publish a release, create or update a pull request, or merge without explicit approval.
- Preserve unrelated local changes in a dirty worktree.

## Xcode Validation

- Prefer Xcode's Issue Navigator for compiler diagnostics.
- After code changes, refresh Issue Navigator first.
- Run a full build when explicitly requested, when Issue Navigator is stale or insufficient, or when new files and cross-target changes require compile confidence.
- Keep the app's archive scheme shared and committed. Never add shared schemes to `.gitignore`.

## Git

- Use Conventional Commits unless the repository history establishes a different convention.
- Include a commit body with concise bullets describing the detailed changes.
- Do not add AI attribution to commits, pull requests, or review comments.
- Keep local branches private until the user explicitly asks to push or open a pull request.

## Releases

- Keep version bumps, build-number changes, and `.github/release-notes.md` out of bug-fix and feature PRs, even if they are in a separate commit within the PR.
- Prepare a release only when Clyde explicitly requests one, after the intended bug-fix and feature PRs have merged. Multiple PRs can ship in one release; do not bump versions for each PR.
- For a user-facing release, set a new `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION`. For a build-only release, increment only `CURRENT_PROJECT_VERSION`.
- Put the version/build changes and release notes in a dedicated `chore: release vX.Y.Z` commit.
- A Release PR is not required by default. With explicit approval, push the standalone release commit directly to `main`; use a separate release-only PR when branch protection requires it or Clyde requests one.
- Create the release tag only after the release commit is on `main` and Clyde has explicitly approved tagging and publication.
- Release tags use `vX.Y.Z-build.N` and must match the Xcode project values.
- A tag push triggers a Developer ID-signed, notarized GitHub Release.

## Release Notes

- Write for users rather than contributors.
- Include only meaningful user-facing features, improvements, and fixes.
- Do not mention internal refactors, file organization, CI implementation, or framework names unless they explain visible behavior.
- Order sections as `## New`, `## Improvements`, `## Fixes`, then `## Installation`, omitting empty sections.
- `## Installation` appears only in the GitHub Release; the in-app update description omits it, so the other sections must not refer to it.

## Project

- App: `__APP_NAME__`
- Xcode container: `__PROJECT_PATH__`
- Shared scheme: `__SCHEME__`
- Bundle identifier: `__BUNDLE_ID__`

Add project-specific architecture, testing, data migration, and security guardrails below this section.
