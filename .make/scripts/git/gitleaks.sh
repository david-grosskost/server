#!/usr/bin/env bash
# Installs the pinned gitleaks version into .tools/bin/, used by the secrets
# check of the pre-commit hook. Same version locally and in GitHub Actions.
# The download is verified against the checksums published by gitleaks.
# Does nothing if this version is already installed. make git@hooks runs it.
#
# @usage make git@gitleaks
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

GITLEAKS_VERSION=8.30.1
BIN_DIR=.tools/bin
RELEASES=https://github.com/gitleaks/gitleaks/releases/download

case "$(uname -s)" in
  Linux)                os=linux   ext=tar.gz exe=gitleaks ;;
  Darwin)               os=darwin  ext=tar.gz exe=gitleaks ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ext=zip    exe=gitleaks.exe ;;
  *) die "git@gitleaks : système non pris en charge ($(uname -s))" ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  arch=x64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) die "git@gitleaks : processeur non pris en charge ($(uname -m))" ;;
esac

if [ -x "$BIN_DIR/$exe" ] \
  && [ "$("$BIN_DIR/$exe" version 2>/dev/null)" = "$GITLEAKS_VERSION" ]; then
  info "gitleaks $GITLEAKS_VERSION déjà installé ($BIN_DIR/$exe)."
  exit 0
fi

asset="gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.${ext}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run curl -sSfL -o "$tmp/$asset" "$RELEASES/v$GITLEAKS_VERSION/$asset"
curl -sSfL -o "$tmp/checksums.txt" \
  "$RELEASES/v$GITLEAKS_VERSION/gitleaks_${GITLEAKS_VERSION}_checksums.txt"

expected="$(awk -v f="$asset" '$2 == f { print $1 }' "$tmp/checksums.txt")"
actual="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
[ -n "$expected" ] && [ "$actual" = "$expected" ] \
  || die "git@gitleaks : empreinte SHA-256 invalide pour $asset, installation annulée"

if [ "$ext" = zip ]; then
  if command -v unzip >/dev/null; then
    unzip -q -o "$tmp/$asset" "$exe" -d "$tmp"
  else
    powershell.exe -NoProfile -Command \
      "Expand-Archive -Force -Path '$(cygpath -w "$tmp/$asset")' -DestinationPath '$(cygpath -w "$tmp")'"
  fi
else
  tar -xzf "$tmp/$asset" -C "$tmp" --no-same-owner "$exe"
fi

mkdir -p "$BIN_DIR"
mv -f "$tmp/$exe" "$BIN_DIR/$exe"
chmod +x "$BIN_DIR/$exe"
info "gitleaks $GITLEAKS_VERSION installé dans $BIN_DIR/ (empreinte vérifiée)."