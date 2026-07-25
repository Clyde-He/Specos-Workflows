# Setup

## Signing certificate

Export the Developer ID Application certificate and private key from Keychain Access as a password-protected `.p12`. Store its base64 representation in `DEVELOPER_ID_CERTIFICATE_BASE64` and its export password in `DEVELOPER_ID_CERTIFICATE_PASSWORD`.

The workflow creates an isolated temporary keychain with a randomly generated password. A shared `BUILD_KEYCHAIN_PASSWORD` secret is not required.

## Notarization key

Create an App Store Connect API key that can submit software to the Apple notary service. Configure its key ID and issuer ID as repository secrets, and store the complete `.p8` content in `APP_STORE_CONNECT_PRIVATE_KEY`.

## macOS app template

`templates/macos-app` is inert during reusable workflow runs. It is copied only when `scripts/new-macos-app.sh` is run explicitly.

The generated repository includes its own thin caller workflow, CI baseline, release notes, release documentation, `AGENTS.md`, `.gitignore`, and one-time secret configuration helper.

## Private Swift packages

Callers that resolve private Swift packages over HTTPS can pass the optional
`swift_package_token` workflow secret. Store a fine-grained GitHub token in
`SWIFT_PACKAGE_TOKEN`, limit it to the required package repositories, and
grant only read-only Contents access.

Use the setup helper's opt-in prompt:

```bash
./scripts/configure-release-secrets.sh Clyde-He/Example-App \
  --with-swift-package-token
```

The workflow keeps the temporary Git URL rewrite in an isolated runner config
file and removes it after the release job.

## Caller rollout

1. Confirm that the app's archive scheme is shared and committed.
2. If the app uses capabilities that require Developer ID provisioning
   profiles, such as App Groups, set `allow_provisioning_updates: true` in the
   caller workflow. The App Store Connect API key must have access to
   Certificates, Identifiers & Profiles.
3. Add the thin caller workflow.
4. Configure the variable and secrets.
5. Publish this repository and push a versioned workflow tag, such as `v1.1.1`.
6. Reference that immutable version from a test caller.
7. After a successful signed and notarized test release, update the moving `v1` tag if desired.

Do not point production callers at `main`.
