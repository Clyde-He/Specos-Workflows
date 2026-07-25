# Agent Instructions

## Scope

- Keep this repository focused on reusable engineering automation and project templates.
- Keep reusable workflows under `.github/workflows/` and project skeletons under `templates/`.
- Treat signing, notarization, and release publication as security-sensitive operations.
- Keep app-specific settings in workflow inputs; do not hard-code a product name, bundle identifier, Xcode project, or scheme.
- A caller using a reusable workflow must not implicitly depend on files under `templates/`.

## Validation

- Validate every changed shell block with `bash -n` after extracting it or moving it into a script.
- Validate workflow YAML with `actionlint` when it is available.
- Run `scripts/new-macos-app.sh` against a temporary destination after changing the macOS app template or generator.
- Exercise changes from a test tag in a caller repository before moving a stable release tag such as `v1`.
- A GitHub release workflow must fail closed: missing signing or notarization credentials must never produce a published release.

## Security

- Pass untrusted GitHub context values through environment variables instead of interpolating them directly into shell scripts.
- Never print certificates, passwords, App Store Connect private keys, or decoded secret material.
- Keep temporary credentials under `RUNNER_TEMP` and remove the temporary keychain and private-key files in an `always()` cleanup step.
- Preserve the caller project's entitlements and sandbox setting. Do not globally disable App Sandbox.

## Git

- Use Conventional Commits with a short body describing the detailed changes.
- Do not push, create a release tag, or publish a GitHub Release without explicit approval.
- Use immutable version tags for consumers. Update the moving major tag only after the versioned tag has been validated.
