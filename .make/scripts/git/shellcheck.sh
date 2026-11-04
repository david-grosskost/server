#!/usr/bin/env bash
# Installs the pinned shellcheck version into .tools/bin/, used by the
# scripts lint of the pre-commit hook. shellcheck publishes no checksums:
# the SHA-256 of each official v0.11.0 archive is pinned below.
# Does nothing if this version is already installed. make git@hooks runs it.
#
# @usage make git@shellcheck
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

SHELLCHECK_VERSION=0.11.0
BIN_DIR=.tools/bin
RELEASES=https://github.com/koalaman/shellcheck/releases/download

case "$(uname -s)" in
  Linux)                os=linux   exe=shellcheck ;;
  Darwin)               os=darwin  exe=shellcheck ;;
  MINGW*|MSYS*|CYGWIN*) os=windows exe=shellcheck.exe ;;
  *) die "git@shellcheck : système non pris en charge ($(uname -s))" ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  arch=x86_64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) die "git@shellcheck : processeur non pris en charge ($(uname -m))" ;;
esac

if [ "$os" = windows ]; then
  [ "$arch" = x86_64 ] || die "git@shellcheck : Windows ARM non pris en charge par shellcheck"
  asset="shellcheck-v$SHELLCHECK_VERSION.zip"
else
  asset="shellcheck-v$SHELLCHECK_VERSION.$os.$arch.tar.xz"
fi

case "$asset" in
  shellcheck-v0.11.0.linux.x86_64.tar.xz)   sha256=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 ;;
  shellcheck-v0.11.0.linux.aarch64.tar.xz)  sha256=12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588 ;;
  shellcheck-v0.11.0.darwin.x86_64.tar.xz)  sha256=3c89db4edcab7cf1c27bff178882e0f6f27f7afdf54e859fa041fca10febe4c6 ;;
  shellcheck-v0.11.0.darwin.aarch64.tar.xz) sha256=56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79 ;;
  shellcheck-v0.11.0.zip)                   sha256=8a4e35ab0b331c85d73567b12f2a444df187f483e5079ceffa6bda1faa2e740e ;;
  *) die "git@shellcheck : pas d'empreinte connue pour $asset" ;;
esac

if [ -x "$BIN_DIR/$exe" ] \
  && "$BIN_DIR/$exe" --version 2>/dev/null | grep -qx "version: $SHELLCHECK_VERSION"; then
  info "shellcheck $SHELLCHECK_VERSION déjà installé ($BIN_DIR/$exe)."
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run curl -sSfL -o "$tmp/$asset" "$RELEASES/v$SHELLCHECK_VERSION/$asset"

[ "$(sha256sum "$tmp/$asset" | cut -d' ' -f1)" = "$sha256" ] \
  || die "git@shellcheck : empreinte SHA-256 invalide pour $asset, installation annulée"

if [ "$os" = windows ]; then
  if command -v unzip >/dev/null; then
    unzip -q -o "$tmp/$asset" "$exe" -d "$tmp"
  else
    powershell.exe -NoProfile -Command \
      "Expand-Archive -Force -Path '$(cygpath -w "$tmp/$asset")' -DestinationPath '$(cygpath -w "$tmp")'"
  fi
  extracted="$tmp/$exe"
else
  tar -xJf "$tmp/$asset" -C "$tmp" --no-same-owner
  extracted="$tmp/shellcheck-v$SHELLCHECK_VERSION/$exe"
fi

mkdir -p "$BIN_DIR"
mv -f "$extracted" "$BIN_DIR/$exe"
chmod +x "$BIN_DIR/$exe"
info "shellcheck $SHELLCHECK_VERSION installé dans $BIN_DIR/ (empreinte vérifiée)."
