#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/bootstrap.sh \
    --name "Example App" \
    --project "Example App.xcodeproj" \
    --scheme "Example App" \
    --bundle-id "design.specos.example"
USAGE
}

app_name=""
project_path=""
scheme=""
bundle_id=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --name)
      app_name="${2:-}"
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
    --bundle-id)
      bundle_id="${2:-}"
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

if [[ -z "$app_name" || -z "$bundle_id" ]]; then
  usage >&2
  exit 1
fi

project_path="${project_path:-$app_name.xcodeproj}"
scheme="${scheme:-$app_name}"

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

python3 - "$app_name" "$project_path" "$scheme" "$bundle_id" <<'PY'
from pathlib import Path
import sys

app_name, project_path, scheme, bundle_id = sys.argv[1:]
replacements = {
    "__APP_NAME__": app_name,
    "__PROJECT_PATH__": project_path,
    "__SCHEME__": scheme,
    "__BUNDLE_ID__": bundle_id,
}
files = [
    Path("AGENTS.md"),
    Path("README.md"),
    Path(".github/workflows/ci.yml"),
    Path(".github/workflows/release.yml"),
    Path("docs/release.md"),
]

changed = False
for file_path in files:
    if not file_path.is_file():
        raise SystemExit(f"Template file is missing: {file_path}")

    contents = file_path.read_text()
    updated = contents
    for token, value in replacements.items():
        updated = updated.replace(token, value)

    if updated != contents:
        file_path.write_text(updated)
        changed = True

remaining = []
for file_path in files:
    contents = file_path.read_text()
    for token in replacements:
        if token in contents:
            remaining.append(f"{file_path}: {token}")

if remaining:
    raise SystemExit("Unresolved template tokens:\n" + "\n".join(remaining))

if not changed:
    raise SystemExit("No template tokens were found. This repository may already be bootstrapped.")
PY

if [[ -e "$project_path" ]]; then
  if ! find . -path "*/xcshareddata/xcschemes/$scheme.xcscheme" -print -quit | grep -q .; then
    echo "Warning: $scheme is not committed as a shared scheme yet." >&2
  fi
else
  echo "Next: create $project_path and share the $scheme scheme."
fi

echo "Bootstrapped $app_name ($bundle_id)."
