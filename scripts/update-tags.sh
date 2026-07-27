#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/update-tags.sh [--check] [--staged]

Generate _data/tags.yml from block-list tags in _posts/*.md front matter.

  --check   Report whether the generated file is current without changing it.
  --staged  Read posts from the Git index instead of the working tree.
EOF
}

check_only=0
source_mode="working-tree"

while (($# > 0)); do
  case "$1" in
    --check)
      check_only=1
      ;;
    --staged)
      source_mode="staged"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
output_file="${repo_root}/_data/tags.yml"
temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/update-tags.XXXXXX")"
rows_file="${temporary_dir}/tag-posts.tsv"
unique_rows_file="${temporary_dir}/unique-tag-posts.tsv"
qualified_tags_file="${temporary_dir}/qualified-tags.txt"
generated_file="${temporary_dir}/tags.yml"

cleanup() {
  rm -rf "${temporary_dir}"
}
trap cleanup EXIT

: >"${rows_file}"

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

parse_tag_value() {
  local source_path="$1"
  local line_number="$2"
  local value
  local first_character
  local last_character

  value="$(trim_whitespace "$3")"
  if [[ -z "${value}" ]]; then
    echo "${source_path}:${line_number}: tag values must not be empty" >&2
    return 1
  fi

  first_character="${value:0:1}"
  last_character="${value: -1}"

  if [[ "${first_character}" == "\"" || "${first_character}" == "'" ]]; then
    if [[ "${last_character}" != "${first_character}" || ${#value} -lt 2 ]]; then
      echo "${source_path}:${line_number}: unterminated quoted tag" >&2
      return 1
    fi
    value="${value:1:${#value}-2}"
    if [[ "${value}" == *"${first_character}"* || "${value}" == *'\'* ]]; then
      echo "${source_path}:${line_number}: escaped or embedded quotes are not supported in tags" >&2
      return 1
    fi
  elif [[ "${value}" == *'#'* ]]; then
    echo "${source_path}:${line_number}: inline comments are not supported in tags" >&2
    return 1
  fi

  if [[ -z "${value}" || "${value}" == *$'\t'* ]]; then
    echo "${source_path}:${line_number}: invalid tag value" >&2
    return 1
  fi

  printf '%s' "${value}"
}

extract_post_tags() {
  local source_path="$1"
  local line
  local line_number=0
  local found_closing_delimiter=0
  local found_tags=0
  local in_tags=0
  local tag_count=0
  local raw_value
  local tag

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_number=$((line_number + 1))
    line="${line%$'\r'}"

    if ((line_number == 1)); then
      if [[ "${line}" != "---" ]]; then
        echo "${source_path}:1: expected YAML front matter delimiter" >&2
        return 1
      fi
      continue
    fi

    if [[ "${line}" == "---" ]]; then
      found_closing_delimiter=1
      break
    fi

    if ((in_tags)); then
      if [[ "${line}" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
        raw_value="${BASH_REMATCH[1]}"
        tag="$(parse_tag_value "${source_path}" "${line_number}" "${raw_value}")"
        printf '%s\t%s\n' "${tag}" "${source_path}" >>"${rows_file}"
        tag_count=$((tag_count + 1))
        continue
      fi

      if [[ -z "${line}" ]]; then
        continue
      fi

      if [[ "${line}" == [[:space:]]* ]]; then
        echo "${source_path}:${line_number}: tags must use a YAML block list" >&2
        return 1
      fi

      in_tags=0
    fi

    if [[ "${line}" =~ ^tags:[[:space:]]*$ ]]; then
      if ((found_tags)); then
        echo "${source_path}:${line_number}: duplicate tags key" >&2
        return 1
      fi
      found_tags=1
      in_tags=1
      continue
    fi

    if [[ "${line}" =~ ^tags: ]]; then
      echo "${source_path}:${line_number}: tags must use a YAML block list" >&2
      return 1
    fi
  done

  if ((!found_closing_delimiter)); then
    echo "${source_path}: missing closing YAML front matter delimiter" >&2
    return 1
  fi

  if ((found_tags && tag_count == 0)); then
    echo "${source_path}: tags must contain at least one item" >&2
    return 1
  fi
}

if [[ "${source_mode}" == "staged" ]]; then
  if ! git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "--staged requires a Git working tree" >&2
    exit 1
  fi

  staged_paths_file="${temporary_dir}/staged-posts.txt"
  git -C "${repo_root}" ls-files --cached -- '_posts/*.md' >"${staged_paths_file}"

  while IFS= read -r relative_path; do
    [[ -n "${relative_path}" ]] || continue
    git -C "${repo_root}" show ":${relative_path}" |
      extract_post_tags "${relative_path}"
  done <"${staged_paths_file}"
else
  shopt -s nullglob
  post_paths=("${repo_root}"/_posts/*.md)
  shopt -u nullglob

  for post_path in "${post_paths[@]}"; do
    relative_path="${post_path#"${repo_root}/"}"
    extract_post_tags "${relative_path}" <"${post_path}"
  done
fi

LC_ALL=C sort -u "${rows_file}" >"${unique_rows_file}"

if [[ -s "${unique_rows_file}" ]]; then
  cut -f1 "${unique_rows_file}" |
    LC_ALL=C sort |
    uniq -c |
    awk '$1 >= 2 { sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); print }' |
    LC_ALL=C sort -f >"${qualified_tags_file}"
else
  : >"${qualified_tags_file}"
fi

{
  echo '# Generated by scripts/update-tags.sh; do not edit manually.'
  echo '# Only tags used by at least two distinct posts are listed.'
  while IFS= read -r tag; do
    escaped_tag="${tag//\\/\\\\}"
    escaped_tag="${escaped_tag//\"/\\\"}"
    printf -- '- "%s"\n' "${escaped_tag}"
  done <"${qualified_tags_file}"
} >"${generated_file}"

if [[ -f "${output_file}" ]] && cmp -s "${generated_file}" "${output_file}"; then
  exit 0
fi

if ((check_only)); then
  echo "${output_file#"${repo_root}/"} is stale; run scripts/update-tags.sh" >&2
  if [[ -f "${output_file}" ]]; then
    diff -u "${output_file}" "${generated_file}" >&2 || true
  fi
  exit 1
fi

mkdir -p "$(dirname "${output_file}")"
mv "${generated_file}" "${output_file}"
echo "Updated ${output_file#"${repo_root}/"}."
