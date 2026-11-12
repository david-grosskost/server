#!/usr/bin/env bash
# Prepares the backups, once per server: generates the repository password
# (secrets/restic-password), creates the restic repository, and shares the
# data directory (dumps, cache) with the docker group: the nightly backup
# runs as this user, the one before each deployment as the deploy user.
# Does nothing that already exists: safe to run again (asks for sudo).
#
# @usage make backup@init
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

command -v docker >/dev/null || die "backup@init : Docker introuvable"
command -v openssl >/dev/null || die "backup@init : openssl introuvable"

if [ -f "$BACKUP_PASSWORD_FILE" ]; then
  info "Mot de passe déjà présent ($BACKUP_PASSWORD_FILE)."
else
  mkdir -p "$(dirname "$BACKUP_PASSWORD_FILE")"
  # Unreadable by others: whoever has it can read every backup.
  ( umask 077 && openssl rand -base64 32 > "$BACKUP_PASSWORD_FILE" )
  info "Mot de passe généré dans $BACKUP_PASSWORD_FILE."
fi

# "cat config" only succeeds on an existing repository.
if restic_run cat config >/dev/null 2>&1; then
  info "Dépôt restic déjà créé ($BACKUP_REPOSITORY)."
else
  restic_run init
  info "Dépôt restic créé ($BACKUP_REPOSITORY)."
fi

# Shared with every member of the docker group (this user, the deploy user):
# group-writable, and new files and directories keep the group (setgid).
mkdir -p "$BACKUP_DUMP_DIR" "$BACKUP_CACHE_DIR"
run sudo chgrp -R docker data
run sudo chmod -R g+rwX data
run sudo find data -type d -exec chmod g+s {} +
info "data/ partagé avec le groupe docker (sauvegarde nocturne et déploiements)."

cat <<MSG

  Sans ce mot de passe, les sauvegardes sont illisibles, même pour toi.
  Copie-le dans ton gestionnaire de mots de passe (jamais dans un chat ni un dépôt) :
    cat $PWD/$BACKUP_PASSWORD_FILE

MSG
# Run alone: what comes next. make app@install does it right after.
if [ -z "${APP_INSTALL:-}" ]; then
  info "Ensuite : make backup@run (première sauvegarde), puis make backup@schedule (chaque nuit)."
  printf '\n'
fi
