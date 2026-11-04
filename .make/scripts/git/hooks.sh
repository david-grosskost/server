#!/usr/bin/env bash
# Enables the versioned Git hooks of .githooks/ and installs the tools they
# use (gitleaks, shellcheck).
# Once per clone.
#
# @usage make git@hooks
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

git rev-parse --git-dir >/dev/null 2>&1 \
  || die "git@hooks : ce dossier n'est pas un dépôt Git"

run git config core.hooksPath .githooks
"$SCRIPTS/git/gitleaks.sh"
"$SCRIPTS/git/shellcheck.sh"
info "Hooks Git activés : messages de commit, scripts, fichiers sensibles et secrets vérifiés."