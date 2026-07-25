# Setup

## Signing certificate

Export the Developer ID Application certificate and private key from Keychain Access as a password-protected `.p12`. Store its base64 representation in `DEVELOPER_ID_CERTIFICATE_BASE64` and its export password in `DEVELOPER_ID_CERTIFICATE_PASSWORD`.

The workflow creates an isolated temporary keychain with a randomly generated password. A shared `BUILD_KEYCHAIN_PASSWORD` secret is not required.

## Notarization key

Create an App Store Connect API key that can submit software to the Apple notary service. Configure its key ID and issuer ID as repository secrets, and store the complete `.p8` content in `APP_STORE_CONNECT_PRIVATE_KEY`.

## macOS app template

`templates/macos-app` is inert during reusable workflow runs. It is copied only when `scripts/new-macos-app.sh` is run explicitly.

The generated repository includes its own thin caller workflow, CI baseline, release notes, release documentation, `AGENTS.md`, `.gitignore`, and one-time secret configuration helper.

## Caller rollout

1. Confirm that the app's archive scheme is shared and committed.
2. Add the thin caller workflow.
3. Configure the variable and secrets.
4. Publish this repository and push a versioned workflow tag, such as `v1.0.0`.
5. Reference that immutable version from a test caller.
6. After a successful signed and notarized test release, update the moving `v1` tag if desired.

Do not point production callers at `main`.
