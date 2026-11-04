#!/usr/bin/env bash
# Rejects a commit whose shell scripts (*.sh and .githooks/*) are broken:
# not executable in Git, wrong first line, or leftover conflict markers.
# Checks what is staged, not the working tree. lib.sh is sourced, never
# executed: only the conflict markers are checked in it.
# Run by .githooks/pre-commit.
#
# @param string $1 --all to check every tracked script instead of the staged ones (CI)
set -euo pipefail

SHEBANG='#!/usr/bin/env bash'

if [ "${1:-}" = --all ]; then
  files="$(git ls-files -- '*.sh' .githooks)"
else
  files="$(git diff --cached --name-only --diff-filter=ACMR -- '*.sh' .githooks)"
fi

failed=0

# Prints an error about a file and marks the check as failed.
#
# @param string $1 File
# @param string $2 Message
fail () { printf 'pre-commit : %s\n  %s\n' "$1" "$2" >&2; failed=1; }

while IFS= read -r file; do
  [ -n "$file" ] || continue

  if [ "$(basename "$file")" != lib.sh ]; then
    mode="$(git ls-files -s -- "$file" | cut -d' ' -f1)"
    [ "$mode" = 100755 ] \
      || fail "$file" "non exécutable dans Git ($mode) → git update-index --chmod=+x $file"

    first="$(git show ":$file" | head -n1 | tr -d '\r')"
    [ "$first" = "$SHEBANG" ] \
      || fail "$file" "première ligne « $first », attendu « $SHEBANG »"
  fi

  if markers="$(git show ":$file" | grep -nE '^(<<<<<<<|>>>>>>>)( |$)')"; then
    fail "$file" "marqueurs de conflit oubliés, lignes : $(cut -d: -f1 <<<"$markers" | paste -sd' ')"
  fi
done <<<"$files"

exit "$failed"
