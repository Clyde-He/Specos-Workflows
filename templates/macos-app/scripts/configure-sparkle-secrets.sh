#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [owner/repository] --bundle-id <bundle-id> [--reset-r2-credentials]" >&2
}

for command_name in gh security; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required." >&2
    exit 1
  fi
done

# One R2 token serves every app's updates, so it is kept in the login Keychain after the first run.
keychain_service="Specos Sparkle R2"

repository=""
bundle_id=""
reset_r2_credentials=false
key_export_dir=""

cleanup_key_export() {
  if [[ -n "$key_export_dir" && -d "$key_export_dir" ]]; then
    find "$key_export_dir" -type f -delete
    rmdir "$key_export_dir"
  fi
}

trap cleanup_key_export EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id)
      if [[ $# -lt 2 ]]; then
        usage
        exit 1
      fi
      bundle_id="$2"
      shift 2
      ;;
    --reset-r2-credentials)
      reset_r2_credentials=true
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$repository" ]]; then
        echo "Only one repository may be specified." >&2
        exit 1
      fi
      repository="$1"
      shift
      ;;
  esac
done

if [[ ! "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "A bundle identifier is required, such as --bundle-id design.specos.example." >&2
  usage
  exit 1
fi

gh auth status

if [[ -z "$repository" ]]; then
  repository="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

read_r2_value() {
  security find-generic-password -s "$keychain_service" -a "$1" -w 2>/dev/null || true
}

store_r2_value() {
  # security -i reads the command from stdin, which keeps the value out of the process list.
  printf 'add-generic-password -U -s "%s" -a "%s" -w "%s"\n' "$keychain_service" "$1" "$2" |
    security -i >/dev/null

  if [[ "$(read_r2_value "$1")" != "$2" ]]; then
    echo "Could not save $1 to the login Keychain." >&2
    exit 1
  fi
}

r2_account_id=""
r2_access_key_id=""
r2_secret_access_key=""
if [[ "$reset_r2_credentials" != "true" ]]; then
  r2_account_id="$(read_r2_value account-id)"
  r2_access_key_id="$(read_r2_value access-key-id)"
  r2_secret_access_key="$(read_r2_value secret-access-key)"
fi

if [[ -n "$r2_account_id" && -n "$r2_access_key_id" && -n "$r2_secret_access_key" ]]; then
  echo "Using R2 credentials saved in the login Keychain as \"$keychain_service\"."
else
  echo "Enter the R2 API token for the update bucket. It is saved in the login Keychain for later apps."
  read -r -p "R2 account ID: " r2_account_id
  read -r -p "R2 access key ID: " r2_access_key_id
  read -r -s -p "R2 secret access key: " r2_secret_access_key
  echo

  if [[ ! "$r2_account_id" =~ ^[0-9a-f]{32}$ ]]; then
    echo "The R2 account ID must be a 32-character Cloudflare account ID." >&2
    exit 1
  fi

  if [[ ! "$r2_access_key_id" =~ ^[A-Za-z0-9]+$ || ! "$r2_secret_access_key" =~ ^[A-Za-z0-9]+$ ]]; then
    echo "The R2 access key ID and secret access key must be the alphanumeric values shown when the token was created." >&2
    exit 1
  fi

  store_r2_value account-id "$r2_account_id"
  store_r2_value access-key-id "$r2_access_key_id"
  store_r2_value secret-access-key "$r2_secret_access_key"
fi

generate_keys="${SPARKLE_GENERATE_KEYS:-}"
if [[ -z "$generate_keys" ]]; then
  generate_keys="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys' \
    -type f -print -quit 2>/dev/null || true)"
fi

if [[ -z "$generate_keys" || ! -x "$generate_keys" ]]; then
  echo "Sparkle's generate_keys was not found. Add Sparkle to an app with Swift Package Manager and resolve packages, or set SPARKLE_GENERATE_KEYS." >&2
  exit 1
fi

# Each app signs with its own key, stored in the login Keychain under its bundle identifier.
if public_key="$("$generate_keys" --account "$bundle_id" -p 2>/dev/null)"; then
  echo "Using the existing Sparkle key for $bundle_id."
else
  echo "Generating a Sparkle key for $bundle_id."
  "$generate_keys" --account "$bundle_id" >/dev/null
  public_key="$("$generate_keys" --account "$bundle_id" -p)"
fi
public_key="$(printf '%s' "$public_key" | tr -d '[:space:]')"

key_export_dir="$(mktemp -d)"
"$generate_keys" --account "$bundle_id" -x "$key_export_dir/sparkle-private-key" >/dev/null
gh secret set SPARKLE_PRIVATE_KEY --repo "$repository" < "$key_export_dir/sparkle-private-key"

printf '%s' "$r2_account_id" |
  gh secret set R2_ACCOUNT_ID --repo "$repository"
printf '%s' "$r2_access_key_id" |
  gh secret set R2_ACCESS_KEY_ID --repo "$repository"
printf '%s' "$r2_secret_access_key" |
  gh secret set R2_SECRET_ACCESS_KEY --repo "$repository"

cat <<EOF
Configured Sparkle and R2 secrets for $repository.

Add the public key to the app's Info.plist:

    <key>SUPublicEDKey</key>
    <string>$public_key</string>

Back up the private key outside this Mac. It is stored in the login Keychain as
"Private key for signing Sparkle updates" (account $bundle_id). Export a copy for
a password manager with:

    "$generate_keys" --account $bundle_id -x <path>
EOF
