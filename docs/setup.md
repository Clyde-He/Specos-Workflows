# Setup

## Signing certificate

Export the Developer ID Application certificate and private key from Keychain Access as a password-protected `.p12`. Store its base64 representation in `DEVELOPER_ID_CERTIFICATE_BASE64` and its export password in `DEVELOPER_ID_CERTIFICATE_PASSWORD`.

The workflow creates an isolated temporary keychain with a randomly generated password. A shared `BUILD_KEYCHAIN_PASSWORD` secret is not required.

Apps with capabilities that require provisioning profiles, such as App Groups,
also need an Apple Development certificate and private key for the
development-signed archive. Export that identity as a password-protected
`.p12`, then store it in `APPLE_DEVELOPMENT_CERTIFICATE_BASE64` and
`APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`.

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

## Sparkle updates

Use one EdDSA key pair per app. Generate it from the app's resolved Sparkle
package, and add the printed public key to the app's Info.plist as
`SUPublicEDKey`:

```bash
generate_keys --account design.specos.example
```

Export the private key once, keep the exported file in a password manager as a
backup, and store it as the caller's `SPARKLE_PRIVATE_KEY` secret. Losing it
strands every installed copy on its current version:

```bash
generate_keys --account design.specos.example -x example-sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY --repo Clyde-He/Example-App < example-sparkle-private-key
```

Delete the exported file after it is backed up.

Create an R2 bucket for updates only, connect the custom domain used by
`SUFeedURL`, and create an R2 API token with Object Read & Write limited to
that bucket. Store the account ID, access key ID, and secret access key in
`R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, and `R2_SECRET_ACCESS_KEY`. Keep personal
or unrelated files out of the bucket, because the token can overwrite any
object in it.

Sandboxed apps also need `SUEnableInstallerLauncherService`, the
`$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and `-spki` mach-lookup exceptions, and
either `SUEnableDownloaderService` or the network client entitlement. See
Sparkle's sandboxing guide.

## Caller rollout

1. Confirm that the app's archive scheme is shared and committed.
2. If the app uses capabilities that require Developer ID provisioning
   profiles, such as App Groups, set `allow_provisioning_updates: true` in the
   caller workflow, pass the Apple Development certificate secrets, and ensure
   the App Store Connect API key has access to Certificates, Identifiers &
   Profiles.
3. Add the thin caller workflow.
4. Configure the variable and secrets.
5. Publish this repository and push a versioned workflow tag, such as `v1.2.0`.
6. Reference that immutable version from a test caller.
7. After a successful signed and notarized test release, update the moving `v1` tag if desired.

Do not point production callers at `main`.
