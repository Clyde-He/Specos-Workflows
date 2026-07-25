#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  exit 1
fi

gh auth status

repository=""
configure_swift_package_token=false
configure_apple_development_certificate=false

for argument in "$@"; do
  case "$argument" in
    --with-apple-development-certificate)
      configure_apple_development_certificate=true
      ;;
    --with-swift-package-token)
      configure_swift_package_token=true
      ;;
    -*)
      echo "Unknown option: $argument" >&2
      exit 1
      ;;
    *)
      if [[ -n "$repository" ]]; then
        echo "Only one repository may be specified." >&2
        exit 1
      fi
      repository="$argument"
      ;;
  esac
done

if [[ -z "$repository" ]]; then
  repository="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

read -r -p "Developer ID .p12 path: " certificate_path
read -r -s -p "Developer ID .p12 password: " certificate_password
echo
read -r -p "App Store Connect AuthKey .p8 path: " private_key_path
read -r -p "App Store Connect key ID: " key_id
read -r -p "App Store Connect issuer ID: " issuer_id
read -r -p "Apple Developer team ID: " team_id
development_certificate_path=""
development_certificate_password=""
if [[ "$configure_apple_development_certificate" == "true" ]]; then
  read -r -p "Apple Development .p12 path: " development_certificate_path
  read -r -s -p "Apple Development .p12 password: " development_certificate_password
  echo
fi
swift_package_token=""
if [[ "$configure_swift_package_token" == "true" ]]; then
  read -r -s -p "Private Swift package token: " swift_package_token
  echo
fi

if [[ ! -f "$certificate_path" ]]; then
  echo "Certificate not found: $certificate_path" >&2
  exit 1
fi

if [[ ! -f "$private_key_path" ]]; then
  echo "Private key not found: $private_key_path" >&2
  exit 1
fi

if [[ "$configure_apple_development_certificate" == "true" && ! -f "$development_certificate_path" ]]; then
  echo "Apple Development certificate not found: $development_certificate_path" >&2
  exit 1
fi

if [[ -z "$certificate_password" || -z "$key_id" || -z "$issuer_id" || -z "$team_id" ]]; then
  echo "All credential values are required." >&2
  exit 1
fi

if [[ "$configure_swift_package_token" == "true" && -z "$swift_package_token" ]]; then
  echo "The private Swift package token is required when requested." >&2
  exit 1
fi

if [[ "$configure_apple_development_certificate" == "true" && -z "$development_certificate_password" ]]; then
  echo "The Apple Development certificate password is required when requested." >&2
  exit 1
fi

base64 < "$certificate_path" |
  gh secret set DEVELOPER_ID_CERTIFICATE_BASE64 --repo "$repository"
printf '%s' "$certificate_password" |
  gh secret set DEVELOPER_ID_CERTIFICATE_PASSWORD --repo "$repository"
gh secret set APP_STORE_CONNECT_PRIVATE_KEY --repo "$repository" < "$private_key_path"
printf '%s' "$key_id" |
  gh secret set APP_STORE_CONNECT_KEY_ID --repo "$repository"
printf '%s' "$issuer_id" |
  gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$repository"
gh variable set APPLE_TEAM_ID --body "$team_id" --repo "$repository"

if [[ "$configure_apple_development_certificate" == "true" ]]; then
  base64 < "$development_certificate_path" |
    gh secret set APPLE_DEVELOPMENT_CERTIFICATE_BASE64 --repo "$repository"
  printf '%s' "$development_certificate_password" |
    gh secret set APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD --repo "$repository"
fi

if [[ "$configure_swift_package_token" == "true" ]]; then
  printf '%s' "$swift_package_token" |
    gh secret set SWIFT_PACKAGE_TOKEN --repo "$repository"
fi

echo "Configured release credentials for $repository."
