#!/usr/bin/env bash
set -euo pipefail

image_name="${IMAGE_NAME:-tbarabosch-github-io-jekyll}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v container >/dev/null 2>&1; then
  echo "Apple Containers CLI not found. Install or start Apple Containers first." >&2
  exit 1
fi

container system start >/dev/null 2>&1 || true
container build -t "${image_name}" "${repo_root}"
container run --rm \
  --volume "${repo_root}:/workspace" \
  --workdir /workspace \
  "${image_name}" \
  bash -lc 'bundle install && bundle exec jekyll build --trace'
