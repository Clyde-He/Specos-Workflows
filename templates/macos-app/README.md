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

Each pull request builds the Debug and Release configurations without code signing on Xcode 27 and Xcode 26, and fails on warnings in the app's own sources. It runs the scheme's tests once the scheme has test targets, and `swift test` for a `Package.swift` at the repository root. A release runs the same tests on its tag before archiving. Add project-specific jobs beside `build` in `.github/workflows/ci.yml`.

## Release

After feature and bug-fix PRs have merged, prepare a requested release in a separate `chore: release vX.Y.Z` commit on `main`. Release preparation needs a separate PR only when branch protection requires one or Clyde requests it. With approval to tag and publish, push a matching tag:

```bash
git tag vX.Y.Z-build.N
git push origin vX.Y.Z-build.N
```

See [docs/release.md](docs/release.md) for the complete release contract.
