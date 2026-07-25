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

- User-facing changes require a new `MARKETING_VERSION` and an incremented `CURRENT_PROJECT_VERSION`.
- Build-only releases increment only `CURRENT_PROJECT_VERSION`.
- Prepare release changes in a dedicated `chore: release vX.Y.Z` commit.
- Release tags use `vX.Y.Z-build.N` and must match the Xcode project values.
- Update `.github/release-notes.md` with user-facing language before tagging.
- A tag push triggers a Developer ID-signed, notarized GitHub Release.

## Release Notes

- Write for users rather than contributors.
- Include only meaningful user-facing features, improvements, and fixes.
- Do not mention internal refactors, file organization, CI implementation, or framework names unless they explain visible behavior.
- Order sections as `## New`, `## Improvements`, `## Fixes`, then `## Installation`, omitting empty sections.

## Project

- App: `__APP_NAME__`
- Xcode container: `__PROJECT_PATH__`
- Shared scheme: `__SCHEME__`
- Bundle identifier: `__BUNDLE_ID__`

Add project-specific architecture, testing, data migration, and security guardrails below this section.
