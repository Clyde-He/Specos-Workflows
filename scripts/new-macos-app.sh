#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/new-macos-app.sh \
    --name "Example App" \
    --bundle-id "design.specos.example" \
    --destination "/path/to/Example-App" \
    [--project "Example App.xcodeproj"] \
    [--scheme "Example App"]
USAGE
}

app_name=""
bundle_id=""
destination=""
project_path=""
scheme=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --name)
      app_name="${2:-}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:-}"
      shift 2
      ;;
    --destination)
      destination="${2:-}"
      shift 2
      ;;
    --project)
      project_path="${2:-}"
      shift 2
      ;;
    --scheme)
      scheme="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$app_name" || -z "$bundle_id" || -z "$destination" ]]; then
  usage >&2
  exit 1
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_root="$repository_root/templates/macos-app"

if [[ ! -d "$template_root" ]]; then
  echo "macOS app template not found: $template_root" >&2
  exit 1
fi

if [[ -e "$destination" ]]; then
  if [[ ! -d "$destination" ]]; then
    echo "Destination exists and is not a directory: $destination" >&2
    exit 1
  fi

  if find "$destination" -mindepth 1 -print -quit | grep -q .; then
    echo "Destination must be empty: $destination" >&2
    exit 1
  fi
else
  mkdir -p "$destination"
fi

ditto "$template_root" "$destination"

bootstrap_arguments=(
  --name "$app_name"
  --bundle-id "$bundle_id"
)

if [[ -n "$project_path" ]]; then
  bootstrap_arguments+=(--project "$project_path")
fi

if [[ -n "$scheme" ]]; then
  bootstrap_arguments+=(--scheme "$scheme")
fi

"$destination/scripts/bootstrap.sh" "${bootstrap_arguments[@]}"

if [[ ! -d "$destination/.git" ]]; then
  git -C "$destination" init -b main
fi

echo
echo "Created $app_name at $destination."
echo "Next: create the Xcode project, share its archive scheme, and configure release credentials."
