#!/usr/bin/env bash
# Marks every script of the repository (tracked file starting with "#!") as
# executable in Git. Windows does not keep the executable bit, so a new script
# is added as 100644 and rejected by the pre-commit hook: run this after git add.
#
# @usage make git@chmod
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

git rev-parse --git-dir >/dev/null 2>&1 \
  || die "git@chmod : ce dossier n'est pas un dépôt Git"

scripts=()
while IFS=$'\t' read -r meta path; do
  [ "${meta%% *}" = 100644 ] || continue
  [ "$(head -c 2 "$path" 2>/dev/null)" = '#!' ] || continue
  scripts+=("$path")
done < <(git ls-files -s)

if [ "${#scripts[@]}" -eq 0 ]; then
  info "Tous les scripts suivis par Git sont déjà exécutables."
  exit 0
fi

run git update-index --chmod=+x "${scripts[@]}"
info "${#scripts[@]} script(s) rendu(s) exécutable(s) dans Git."
