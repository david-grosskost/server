#!/usr/bin/env bash
# Backs up the server: dumps every running MariaDB database, then saves
# BACKUP_SOURCE (/srv) into the restic repository, removes the snapshots out
# of the retention, and checks the repository.
#
# The raw database files (data/db) are not saved: copied while MariaDB runs,
# they may be unusable. The dumps (data/dumps of this project) replace them.
# Caches that SuiteCRM rebuilds are not saved either.
#
# Run each night by the systemd timer (make backup@schedule).
#
# @usage make backup@run
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

# Dumps the database of a MariaDB container into BACKUP_DUMP_DIR/<container>.sql.gz.
# Credentials are read inside the container, from the variables of the
# official image: nothing is printed or written on the host.
#
# @param string $1 Container name
dump_database () {
  local file="$BACKUP_DUMP_DIR/$1.sql.gz"
  info "Dump de la base : $1"
  # Single quotes: expanded inside the container, not here.
  # shellcheck disable=SC2016
  docker exec "$1" sh -c '
    if [ -n "${MARIADB_DATABASE:-}" ]; then set -- --databases "$MARIADB_DATABASE"
    else set -- --all-databases; fi
    MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -uroot \
      --single-transaction --routines --triggers --events "$@"' \
    | gzip > "$file.tmp"
  # Renamed once complete: a failed dump never replaces the previous one.
  mv "$file.tmp" "$file"
}

started="$(date +%s)"
printf '\n  Sauvegarde de %s (%s)\n\n' "$BACKUP_SOURCE" "$(date '+%F %T')"

mkdir -p "$BACKUP_DUMP_DIR"
databases=0
while read -r name image; do
  case $image in
    mariadb|mariadb:*|*/mariadb|*/mariadb:*) dump_database "$name"; databases=$((databases + 1)) ;;
  esac
done < <(docker ps --format '{{.Names}} {{.Image}}')
info "$databases base(s) exportée(s) dans $BACKUP_DUMP_DIR/."

restic_run backup "$BACKUP_SOURCE" \
  --tag nightly \
  --exclude "$BACKUP_REPOSITORY" \
  --exclude "$BACKUP_SOURCE/**/data/db" \
  --exclude "$BACKUP_SOURCE/**/data/app/cache" \
  --exclude "$BACKUP_SOURCE/**/data/app/public/legacy/cache" \
  --exclude-caches

restic_run forget --prune \
  --keep-daily "$BACKUP_KEEP_DAILY" \
  --keep-weekly "$BACKUP_KEEP_WEEKLY" \
  --keep-monthly "$BACKUP_KEEP_MONTHLY"

restic_run check

info "Sauvegarde terminée en $(( $(date +%s) - started )) s."
