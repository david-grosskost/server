#!/usr/bin/env bash
# Backs up the server: dumps every running MariaDB database, then saves
# BACKUP_SOURCE (/srv) into the restic repository, removes the snapshots out
# of the retention, and checks the repository.
#
# The raw database files (data/db) are not saved: copied while MariaDB runs,
# they may be unusable. The dumps (data/dumps of this project) replace them.
# Caches that SuiteCRM rebuilds are not saved either. Only the content of
# these directories is left out: restored, they exist, empty, with their owner.
#
# Run each night by the systemd timer (make backup@schedule), tagged nightly.
# Run by each deployment too (suitecrm-devkit deploy.yml), just before the
# version changes: tagged pre-deploy, without the retention and the check,
# left to the nightly run (quicker, and never blocked by its lock).
# Retention applies to each tag on its own: pre-deploy snapshots never push
# nightly ones out, nor the reverse.
#
# The nightly run signals Healthchecks.io (make backup@alert): start, then
# success or failure with the end of its log. No signal for 25 hours, or a
# failure, sends the alert. The pre-deploy runs send nothing: their success
# must not hide a missed night.
#
# @usage make backup@run [BACKUP_TAG=pre-deploy] [BACKUP_MAINTENANCE=0]
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

BACKUP_TAG="${BACKUP_TAG:-nightly}"
BACKUP_MAINTENANCE="${BACKUP_MAINTENANCE:-1}"
[[ $BACKUP_TAG =~ ^[a-z0-9-]+$ ]] || die "backup@run : BACKUP_TAG invalide : $BACKUP_TAG"

# Files stay writable by the docker group: the next backup may run as
# another user (nightly: the server user, before a deployment: deploy).
umask 002
mkdir -p "$BACKUP_DUMP_DIR"
[ -w "$BACKUP_DUMP_DIR" ] \
  || die "backup@run : $BACKUP_DUMP_DIR non modifiable par $(id -un) → make backup@init (partage data/ avec le groupe docker)"

# Nightly run: signals to Healthchecks.io, and the log for the failure alert.
if [ "$BACKUP_TAG" = nightly ] && [ -f "$BACKUP_PING_FILE" ]; then
  log="$(mktemp)"
  exec > >(tee "$log") 2>&1
  # Status of the script, then the end of its log, sent as the alert text.
  # shellcheck disable=SC2329 # called by the trap
  on_exit () {
    local status=$1
    if [ "$status" = 0 ]; then
      healthcheck_ping "$BACKUP_PING_FILE" "" "$(tail -n 5 "$log")"
    else
      healthcheck_ping "$BACKUP_PING_FILE" /fail "Échec (code $status) :
$(tail -n 30 "$log")"
    fi
    rm -f "$log"
  }
  trap 'on_exit $?' EXIT
  healthcheck_ping "$BACKUP_PING_FILE" /start ""
fi

started="$(date +%s)"
printf '\n  Sauvegarde de %s (%s)\n\n' "$BACKUP_SOURCE" "$(date '+%F %T')"

databases=0
while read -r name image; do
  case $image in
    mariadb|mariadb:*|*/mariadb|*/mariadb:*) dump_database "$name"; databases=$((databases + 1)) ;;
  esac
done < <(docker ps --format '{{.Names}} {{.Image}}')
info "$databases base(s) exportée(s) dans $BACKUP_DUMP_DIR/."

restic_run backup "$BACKUP_SOURCE" \
  --tag "$BACKUP_TAG" \
  --exclude "$BACKUP_DIR" \
  --exclude "$BACKUP_SOURCE/**/data/db/*" \
  --exclude "$BACKUP_SOURCE/**/data/app/cache/*" \
  --exclude "$BACKUP_SOURCE/**/data/app/public/legacy/cache/*" \
  --exclude-caches

if [ "$BACKUP_MAINTENANCE" = 0 ]; then
  info "Sauvegarde $BACKUP_TAG terminée en $(( $(date +%s) - started )) s (rétention et vérification : la nuit)."
  exit 0
fi

restic_run forget --prune --group-by host,paths,tags \
  --keep-daily "$BACKUP_KEEP_DAILY" \
  --keep-weekly "$BACKUP_KEEP_WEEKLY" \
  --keep-monthly "$BACKUP_KEEP_MONTHLY"

restic_run check

info "Sauvegarde terminée en $(( $(date +%s) - started )) s."
