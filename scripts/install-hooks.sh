#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

if ! git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run from a Git checkout." >&2
  exit 1
fi

hook_path="${repo_root}/.githooks/pre-commit"
if [[ ! -x "${hook_path}" ]]; then
  echo "Expected an executable hook at .githooks/pre-commit" >&2
  exit 1
fi

current_hooks_path="$(git -C "${repo_root}" config --get core.hooksPath || true)"
if [[ -n "${current_hooks_path}" && "${current_hooks_path}" != ".githooks" ]]; then
  echo "Refusing to replace existing core.hooksPath: ${current_hooks_path}" >&2
  exit 1
fi

legacy_hook="$(git -C "${repo_root}" rev-parse --git-path hooks/pre-commit)"
if [[ "${legacy_hook}" != /* ]]; then
  legacy_hook="${repo_root}/${legacy_hook}"
fi
if [[ -z "${current_hooks_path}" ]] && { [[ -e "${legacy_hook}" ]] || [[ -L "${legacy_hook}" ]]; }; then
  echo "Refusing to bypass existing hook: .git/hooks/pre-commit" >&2
  exit 1
fi

git -C "${repo_root}" config --local core.hooksPath .githooks
echo "Enabled repository hooks from .githooks."
