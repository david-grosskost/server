#!/usr/bin/env bash
# Rejects a commit whose changes contain a secret (API key, token, private
# key, password…), detected by gitleaks. Secrets are redacted from the output.
# Run by .githooks/pre-commit.
#
# @param string $1 --all to scan the whole Git history instead of the staged changes (CI)
set -euo pipefail

# The project's pinned version (make git@gitleaks) first, then the system one.
if [ -x .tools/bin/gitleaks.exe ]; then
  gitleaks=.tools/bin/gitleaks.exe
elif [ -x .tools/bin/gitleaks ]; then
  gitleaks=.tools/bin/gitleaks
elif command -v gitleaks >/dev/null; then
  gitleaks=gitleaks
else
  printf 'pre-commit : gitleaks introuvable, les secrets ne peuvent pas être vérifiés\n  %s\n' \
    'installer : make git@gitleaks' >&2
  exit 1
fi

if [ "${1:-}" = --all ]; then
  "$gitleaks" git --redact --verbose --no-banner --log-level warn
else
  "$gitleaks" git --pre-commit --staged --redact --verbose --no-banner --log-level warn
fi