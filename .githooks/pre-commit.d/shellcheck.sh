#!/usr/bin/env bash
# Rejects a commit whose shell scripts (*.sh and .githooks/*) have bugs or
# risky constructs found by shellcheck (settings in .shellcheckrc).
# Lints the working tree version of the staged scripts.
# Run by .githooks/pre-commit.
#
# @param string $1 --all to check every tracked script instead of the staged ones (CI)
set -euo pipefail

# The project's pinned version (make git@shellcheck) first, then the system one.
if [ -x .tools/bin/shellcheck.exe ]; then
  shellcheck=.tools/bin/shellcheck.exe
elif [ -x .tools/bin/shellcheck ]; then
  shellcheck=.tools/bin/shellcheck
elif command -v shellcheck >/dev/null; then
  shellcheck=shellcheck
else
  printf 'pre-commit : shellcheck introuvable, les scripts ne peuvent pas être vérifiés\n  %s\n' \
    'installer : make git@shellcheck' >&2
  exit 1
fi

if [ "${1:-}" = --all ]; then
  files="$(git ls-files -- '*.sh' .githooks)"
else
  files="$(git diff --cached --name-only --diff-filter=ACMR -- '*.sh' .githooks)"
fi

[ -n "$files" ] || exit 0

list=()
while IFS= read -r file; do list+=("$file"); done <<<"$files"
"$shellcheck" "${list[@]}"
