#!/usr/bin/env bash
# Fills in your repo URL and the folder path inside your repo.
#
#   ./configure.sh https://github.com/you/your-learning-repo.git appset-ui
#
set -euo pipefail
cd "$(dirname "$0")"

REPO_URL="${1:-}"
DEMO_PATH="${2:-appset-ui}"

if [[ -z "$REPO_URL" ]]; then
  echo "usage: $0 <repo-url> [path-inside-repo]" >&2
  exit 1
fi

for f in manifests/*.yaml app-of-appset/parent-app.yaml app-of-appset/appset/*.yaml; do
  sed -i.bak "s|REPO_URL|${REPO_URL}|g; s|DEMO_PATH|${DEMO_PATH}|g" "$f"
  rm -f "$f.bak"
done

echo "Configured for:"
echo "  repoURL : $REPO_URL"
echo "  path    : $DEMO_PATH"
