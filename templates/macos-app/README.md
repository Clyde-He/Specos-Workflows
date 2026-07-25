# __APP_NAME__

macOS app using a shared build, validation, signing, notarization, and GitHub Release baseline.

## Initial setup

1. Create the macOS Xcode project at `__PROJECT_PATH__`.
2. Name the app archive scheme `__SCHEME__`, mark it as Shared, and commit the generated `.xcscheme`.
3. Configure release credentials:

   ```bash
   ./scripts/configure-release-secrets.sh
   ```

4. Replace this section with product-specific development documentation.

## Validation

Pull requests and pushes to `main` compile the Debug configuration without code signing. Add project-specific unit and integration tests to `.github/workflows/ci.yml`.

## Release

Update `.github/release-notes.md`, bump the Xcode marketing version and build number, commit the release preparation, then push a matching tag:

```bash
git tag vX.Y.Z-build.N
git push origin vX.Y.Z-build.N
```

See [docs/release.md](docs/release.md) for the complete release contract.
