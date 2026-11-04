#!/usr/bin/env bash
# Rejects a commit that adds a file holding secrets: .env, private keys,
# certificates, Let's Encrypt storage. .gitignore already excludes them,
# but `git add -f` bypasses it. .env.example is allowed.
# Run by .githooks/pre-commit.
#
# @param string $1 --all to check every tracked file instead of the staged ones (CI)
set -euo pipefail

if [ "${1:-}" = --all ]; then
  files="$(git ls-files)"
else
  files="$(git diff --cached --name-only --diff-filter=ACMR)"
fi

failed=0

while IFS= read -r file; do
  [ -n "$file" ] || continue

  case "$(basename "$file")" in
    .env.example) continue ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|acme.json|.htpasswd|*.htpasswd \
      |id_rsa|id_ecdsa|id_ed25519) ;;
    *) continue ;;
  esac

  printf 'pre-commit : %s\n  fichier sensible, à ne jamais commiter → git rm --cached %s\n' \
    "$file" "$file" >&2
  failed=1
done <<<"$files"

exit "$failed"