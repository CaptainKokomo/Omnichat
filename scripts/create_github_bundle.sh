#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
BUNDLE_PATH="${ROOT_DIR}/omnichat.bundle"

echo "Creating git bundle at ${BUNDLE_PATH}"
cd "${ROOT_DIR}"

git status --short

if ! git rev-parse --verify main >/dev/null 2>&1; then
  echo "Creating local main branch from current HEAD"
  git branch main >/dev/null 2>&1 || true
fi

git bundle create "${BUNDLE_PATH}" --all --branches

echo "Bundle created. Upload this file to your GitHub repository, then run:\n"
echo "  git clone omnichat.bundle omnichat-upload"
echo "  cd omnichat-upload"
echo "  git remote add origin <git@github.com:Captainkokmo/Omnichat.git>"
echo "  git push --all origin"
