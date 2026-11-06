#!/usr/bin/env bash
# Sets the alert of the nightly backup: asks for the ping URL of the
# Healthchecks.io check (typed, not shown, never in a file of the
# repository), saves it in secrets/healthcheck-backup (readable by this user
# only), then sends a test signal. Run again to change it; type nothing to
# remove the alert. See docs/sauvegardes.md.
#
# @usage make backup@alert
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

cat <<MSG

  Alerte de la sauvegarde nocturne (Healthchecks.io).
  Colle l'adresse de signal du contrôle (« Ping URL », https://hc-ping.com/…),
  puis Entrée. Rien ne s'affiche pendant la saisie. Vide : retire l'alerte.

MSG
read -r -s -p "  Adresse : " url
printf '\n'

if [ -z "$url" ]; then
  rm -f "$BACKUP_PING_FILE"
  info "Alerte retirée : les sauvegardes continuent sans signal."
  exit 0
fi

[[ $url =~ ^https://[A-Za-z0-9.-]+/[A-Za-z0-9/_-]+$ ]] \
  || die "backup@alert : adresse invalide (attendu : https://hc-ping.com/…)"

mkdir -p "$(dirname "$BACKUP_PING_FILE")"
( umask 077 && printf '%s\n' "$url" > "$BACKUP_PING_FILE" )
info "Adresse enregistrée dans $BACKUP_PING_FILE."

# A test signal: the check turns green on Healthchecks.io.
if curl -fsS -m 10 -o /dev/null --data-raw "Test de make backup@alert" "$url"; then
  info "Signal de test envoyé : le contrôle doit être vert sur Healthchecks.io."
else
  die "backup@alert : signal de test non reçu par Healthchecks.io, vérifie l'adresse"
fi
