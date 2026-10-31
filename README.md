# Specos Workflows

Shared automation and project scaffolding for Specos repositories.

This repository currently provides:

- A reusable GitHub Actions workflow for Developer ID signing, Apple notarization, and GitHub Releases.
- A reusable GitHub Actions workflow that builds and tests a macOS app on each pull request.
- A macOS app template with `AGENTS.md`, `.gitignore`, CI, release configuration, documentation, and setup scripts.

The repository contains no certificates, App Store Connect private keys, or caller application source.

## Reusable macOS release

An app repository keeps a thin caller workflow:

```yaml
name: Release

on:
  push:
    tags:
      - "v*-build.*"
  workflow_dispatch:
    inputs:
      tag:
        description: "Existing release tag, such as v1.0-build.1"
        required: true
        type: string

permissions:
  contents: write

jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    permissions:
      contents: read
    with:
      ref: ${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}

  release:
    needs: ci
    uses: Clyde-He/Specos-Workflows/.github/workflows/macos-notarized-release.yml@v1.5.0
    with:
      app_name: Example App
      project_path: Example App.xcodeproj
      scheme: Example App
      expected_bundle_id: design.specos.example
      release_tag: ${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}
      apple_team_id: ${{ vars.APPLE_TEAM_ID }}
    secrets:
      developer_id_certificate_base64: ${{ secrets.DEVELOPER_ID_CERTIFICATE_BASE64 }}
      developer_id_certificate_password: ${{ secrets.DEVELOPER_ID_CERTIFICATE_PASSWORD }}
      apple_development_certificate_base64: ${{ secrets.APPLE_DEVELOPMENT_CERTIFICATE_BASE64 }}
      apple_development_certificate_password: ${{ secrets.APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD }}
      developer_id_provisioning_profiles_base64: ${{ secrets.DEVELOPER_ID_PROVISIONING_PROFILES_BASE64 }}
      app_store_connect_key_id: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
      app_store_connect_issuer_id: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
      app_store_connect_private_key: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
```

The reusable workflow checks out and releases the caller repository. It does not copy or read anything under `templates/`.

The `ci` job runs the caller's own [CI workflow](#reusable-macos-ci) on the release tag first, and `needs: ci` publishes nothing unless it passes. Pull requests already run CI, but `main` is not branch-protected, so this also catches code that reached `main` without one.

The caller must grant `contents: write`; a reusable workflow cannot elevate the caller's token permissions.

The workflow builds on GitHub's `xcode-27` runner and requires Xcode 27, so a release is built with the macOS 27 SDK. That runner image is still a GitHub preview. A caller that must stay on Xcode 26 can set:

```yaml
      runner: macos-26
      minimum_xcode_major: 26
```

Apps with capabilities that require Developer ID provisioning profiles, such
as App Groups, should also set:

```yaml
      allow_provisioning_updates: true
```

The workflow then uses an Apple Development identity to create the
development-signed archive and the App Store Connect authentication key to let
Xcode create or download the required profiles. Xcode exports that archive with
the Developer ID identity. Callers without those capabilities keep the default
manual-signing path.

Apps that compile Metal source on runner images where the optional toolchain is
not preinstalled should also set:

```yaml
      download_metal_toolchain: true
```

### Caller configuration

Create this repository variable:

- `APPLE_TEAM_ID`

Create these repository secrets:

- `DEVELOPER_ID_CERTIFICATE_BASE64`
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`

Configure them interactively from a trusted local checkout:

```bash
./scripts/configure-release-secrets.sh Clyde-He/Example-App
```

For apps that enable `allow_provisioning_updates`, also configure:

- `APPLE_DEVELOPMENT_CERTIFICATE_BASE64`
- `APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`
- `DEVELOPER_ID_PROVISIONING_PROFILES_BASE64`

Pass the corresponding `.p12` to the setup helper:

```bash
./scripts/configure-release-secrets.sh Clyde-He/Example-App \
  --with-apple-development-certificate \
  --with-developer-id-profiles
```

Enter every Developer ID provisioning profile required by the exported app and
its embedded extensions. The helper packs them into one compressed repository
secret; the workflow validates and installs them, then performs a manual export
with the caller's Developer ID certificate.

If the caller resolves private Swift packages over HTTPS, also pass the
optional workflow secret:

```yaml
      swift_package_token: ${{ secrets.SWIFT_PACKAGE_TOKEN }}
```

Configure it together with the release credentials:

```bash
./scripts/configure-release-secrets.sh Clyde-He/Example-App \
  --with-swift-package-token
```

Use a fine-grained token limited to the package repositories with read-only
Contents access.

### Sparkle updates

Apps that ship [Sparkle 2](https://sparkle-project.org) updates can publish
each release to a Cloudflare R2 bucket by also setting:

```yaml
      sparkle_r2_bucket: specos-update
    secrets:
      sparkle_private_key: ${{ secrets.SPARKLE_PRIVATE_KEY }}
      r2_account_id: ${{ secrets.R2_ACCOUNT_ID }}
      r2_access_key_id: ${{ secrets.R2_ACCESS_KEY_ID }}
      r2_secret_access_key: ${{ secrets.R2_SECRET_ACCESS_KEY }}
```

The workflow reads `SUFeedURL` and `SUPublicEDKey` from the exported app,
signs the notarized ZIP with `generate_appcast` from the app's resolved Sparkle
package, adds it to the existing feed, and uploads the ZIP and then the feed.
The bucket must be served at the root of the `SUFeedURL` host, so
`https://updates.specos.design/needle/appcast.xml` is stored as
`needle/appcast.xml`. The release notes file becomes the update's Markdown
description, without its `## Installation` section: users updating from inside
the app do not need download instructions, which stay in the GitHub Release.

A missing credential, a private key that does not match `SUPublicEDKey`, or an
unsigned feed item stops the job before the GitHub Release is published.

Configure the Sparkle key and R2 secrets for a caller with:

```bash
./scripts/configure-sparkle-secrets.sh Clyde-He/Example-App \
  --bundle-id design.specos.example
```

The R2 token is entered once and reused from the login Keychain for later
apps. See [docs/setup.md](docs/setup.md#sparkle-updates).

### Release contract

- The archive scheme is shared and committed.
- The Release configuration enables Hardened Runtime.
- Apps that require Developer ID provisioning profiles enable
  `allow_provisioning_updates`, provide an Apple Development identity, and
  provide Developer ID profiles for the app and embedded extensions.
- Tags use `vMARKETING_VERSION-build.CURRENT_PROJECT_VERSION`.
- The tag exists and points to the commit being built.
- Missing credentials, invalid metadata, an invalid signature, or rejected notarization stops publication.
- The caller's CI passes on the release tag before the release job runs.
- `.github/release-notes.md` is used when present; otherwise GitHub-generated notes are used. Its `## Installation` section appears only in the GitHub Release, not in the Sparkle update.

## Reusable macOS CI

An app repository keeps a thin caller workflow:

```yaml
name: CI

on:
  pull_request:
  workflow_call:
    inputs:
      ref:
        description: "Git ref to test"
        required: true
        type: string

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    uses: Clyde-He/Specos-Workflows/.github/workflows/macos-ci.yml@v1.5.0
    with:
      project_path: Example App.xcodeproj
      scheme: Example App
      ref: ${{ inputs.ref }}
```

It runs on each pull request, and the release workflow calls it with the release tag before publishing. A run on every push to `main` would repeat both on macOS runners. On a pull request `inputs.ref` is empty, so the pull request's own commit is tested.

On each runner in `runners`, the workflow builds the Debug configuration and runs its tests, then builds the Release configuration, with code signing off. It then fails on any warning in the caller's own source files; warnings inside Swift package dependencies are ignored. With `swift_test`, it also runs `swift test` for a Swift package at the repository root with the same Xcode; that run is not checked for warnings. By default it runs on `xcode-27` and `macos-26`, so code that needs the newest SDK must still build with the previous Xcode. Failed tests upload their result bundle as an artifact.

| Input | Default | Purpose |
|---|---|---|
| `runners` | `["xcode-27", "macos-26"]` | JSON array of runner labels, one build per Xcode |
| `ref` | Triggering commit | Git ref to check out, such as the release tag |
| `test` | `true` | Run the scheme's tests in Debug |
| `swift_test` | `false` | Also run `swift test` for the `Package.swift` at the repository root |
| `build_release` | `true` | Also build the Release configuration |
| `warnings_as_errors` | `true` | Fail on warnings in the caller's own source files |

Pass `swift_package_token` under `secrets` when the app depends on private Swift packages. Release calls the caller's CI workflow without secrets, so such a caller also declares the secret under `workflow_call` and the release workflow's `ci` job passes it:

```yaml
# ci.yml
  workflow_call:
    secrets:
      SWIFT_PACKAGE_TOKEN:
        required: false

# release.yml, in the ci job
    secrets:
      SWIFT_PACKAGE_TOKEN: ${{ secrets.SWIFT_PACKAGE_TOKEN }}
```

A repository that needs more than this adds its own jobs beside `build` in the same caller workflow; the release runs them too.

## Create a macOS app repository

Generate a new repository working tree from `templates/macos-app`:

```bash
./scripts/new-macos-app.sh \
  --name "Example App" \
  --bundle-id "design.specos.example" \
  --destination "/path/to/Example-App"
```

Optional `--project` and `--scheme` arguments override the default `Example App.xcodeproj` and `Example App` names.

The generator copies only the macOS app template, resolves its placeholders, and initializes a local Git repository. It does not copy the reusable workflow implementation.

## Repository layout

```text
.github/workflows/
  macos-ci.yml
  macos-notarized-release.yml
templates/
  macos-app/
scripts/
  new-macos-app.sh
  configure-release-secrets.sh
  configure-sparkle-secrets.sh
docs/
  setup.md
```

See [docs/setup.md](docs/setup.md) for signing credentials and rollout guidance.
