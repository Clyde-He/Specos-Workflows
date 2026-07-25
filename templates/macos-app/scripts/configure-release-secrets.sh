#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required." >&2
  exit 1
fi

gh auth status

repository="${1:-}"
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

if [[ ! -f "$certificate_path" ]]; then
  echo "Certificate not found: $certificate_path" >&2
  exit 1
fi

if [[ ! -f "$private_key_path" ]]; then
  echo "Private key not found: $private_key_path" >&2
  exit 1
fi

if [[ -z "$certificate_password" || -z "$key_id" || -z "$issuer_id" || -z "$team_id" ]]; then
  echo "All credential values are required." >&2
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

echo "Configured release credentials for $repository."
