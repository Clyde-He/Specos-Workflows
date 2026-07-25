# Specos Workflows

Shared automation and project scaffolding for Specos repositories.

This repository currently provides:

- A reusable GitHub Actions workflow for Developer ID signing, Apple notarization, and GitHub Releases.
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
  release:
    uses: Clyde-He/Specos-Workflows/.github/workflows/macos-notarized-release.yml@v1.2.1
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
      app_store_connect_key_id: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
      app_store_connect_issuer_id: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
      app_store_connect_private_key: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
```

The reusable workflow checks out and releases the caller repository. It does not copy or read anything under `templates/`.

The caller must grant `contents: write`; a reusable workflow cannot elevate the caller's token permissions.

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

Pass the corresponding `.p12` to the setup helper:

```bash
./scripts/configure-release-secrets.sh Clyde-He/Example-App \
  --with-apple-development-certificate
```

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

### Release contract

- The archive scheme is shared and committed.
- The Release configuration enables Hardened Runtime.
- Apps that require Developer ID provisioning profiles enable
  `allow_provisioning_updates` and provide an Apple Development identity.
- Tags use `vMARKETING_VERSION-build.CURRENT_PROJECT_VERSION`.
- The tag exists and points to the commit being built.
- Missing credentials, invalid metadata, an invalid signature, or rejected notarization stops publication.
- `.github/release-notes.md` is used when present; otherwise GitHub-generated notes are used.

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
  macos-notarized-release.yml
templates/
  macos-app/
scripts/
  new-macos-app.sh
  configure-release-secrets.sh
docs/
  setup.md
```

See [docs/setup.md](docs/setup.md) for signing credentials and rollout guidance.
