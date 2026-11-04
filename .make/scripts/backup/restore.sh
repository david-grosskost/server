#!/usr/bin/env bash
# Puts a SuiteCRM instance back in the state of a backup: its whole directory
# (/srv/suitecrm/<instance>: settings, secrets, files), then its database,
# from the dump saved with it.
#
# 1. Restores the instance and its dump into BACKUP_RESTORE_DIR: nothing in
#    place is touched if the backup is incomplete.
# 2. Stops the instance and moves its directory aside, as
#    <instance>.before-restore-<date>: going back is a rename.
# 3. Puts the restored directory in place, starts the database (empty),
#    imports the dump, then starts the rest and waits until it is healthy.
#
# Asks to type the instance name to confirm, and for sudo: the instance's
# files belong to the containers' users (www-data, mysql).
#
# @usage make backup@restore INSTANCE=demo-core [SNAPSHOT=latest]
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

INSTANCE="${INSTANCE:-}"
SNAPSHOT="${SNAPSHOT:-latest}"

[ -n "$INSTANCE" ] || die "backup@restore : INSTANCE manquant (ex. make backup@restore INSTANCE=demo-core)"
[[ $INSTANCE =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "backup@restore : INSTANCE invalide : $INSTANCE"
[[ $SNAPSHOT =~ ^[a-z0-9]+$ ]] || die "backup@restore : SNAPSHOT invalide : $SNAPSHOT"

instance_dir="$SUITECRM_DIR/$INSTANCE"
dump="$PWD/$BACKUP_DUMP_DIR/$INSTANCE-db.sql.gz"
stamp="$(date +%Y%m%d-%H%M%S)"
staging="$BACKUP_RESTORE_DIR/$INSTANCE-$stamp"
aside="$instance_dir.before-restore-$stamp"

[ -d "$instance_dir" ] || die "backup@restore : $instance_dir absent"

cat <<MSG

  Restauration de $INSTANCE depuis la sauvegarde « $SNAPSHOT ».
  Tout ce qui a changé dans cette instance depuis sera remplacé (fichiers et base).
  L'état actuel reste de côté dans $aside.

MSG
read -r -p "  Pour confirmer, tape le nom de l'instance ($INSTANCE) : " answer
[ "$answer" = "$INSTANCE" ] || die "backup@restore : annulé"

# 1. Restore into the staging directory, then check that everything is there.
sudo mkdir -p "$staging"
RESTIC_DOCKER_ARGS=(-v "$staging:/restore")
restic_run restore "$SNAPSHOT" --target /restore \
  --include "$instance_dir" --include "$dump"
RESTIC_DOCKER_ARGS=()

restored_dir="$staging$instance_dir"
restored_dump="$staging$dump"
sudo test -f "$restored_dir/.env.local" \
  || die "backup@restore : $INSTANCE incomplet dans la sauvegarde (pas de .env.local), rien n'a été modifié"
sudo test -f "$restored_dump" \
  || die "backup@restore : pas de dump de $INSTANCE-db dans la sauvegarde, rien n'a été modifié"

# 2. Stop the instance (by its Compose project name: no file needed), move it aside.
run sudo docker compose -p "$INSTANCE" down
run sudo mv "$instance_dir" "$aside"

# 3. Put the restored directory in place and start it.
run sudo mv "$restored_dir" "$instance_dir"
app_env="$(sudo sed -n 's/^APP_ENV=//p' "$instance_dir/.env.local" | tail -n 1)"
[ -n "$app_env" ] || die "backup@restore : APP_ENV absent de $instance_dir/.env.local"

# Docker Compose on the restored instance, with its env files and overlay.
#
# @param string $@ docker compose arguments
instance_compose () {
  run sudo docker compose --project-directory "$instance_dir" \
    --env-file "$instance_dir/.env" --env-file "$instance_dir/.env.local" \
    -f "$instance_dir/compose.yaml" -f "$instance_dir/compose.$app_env.yaml" "$@"
}

# MariaDB starts on an empty data/db: it creates the database and its user
# from .env.local (the passwords of the backup), then the dump is imported.
instance_compose up -d --wait db
info "Import de la base de $INSTANCE"
# Single quotes: expanded inside the container, not here.
# shellcheck disable=SC2016
sudo gzip -dc "$restored_dump" \
  | sudo docker exec -i "$INSTANCE-db" sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot'

instance_compose up -d --wait --wait-timeout 300

run sudo rm -rf "$staging"

cat <<MSG

  $INSTANCE restaurée depuis la sauvegarde « $SNAPSHOT ».
  Vérifie l'instance, puis supprime l'ancien état :
    sudo rm -rf $aside
  Pour revenir plutôt à l'état d'avant la restauration :
    sudo docker compose -p $INSTANCE down
    sudo mv $instance_dir $instance_dir.restored-$stamp
    sudo mv $aside $instance_dir
    cd $instance_dir && sudo docker compose --env-file .env --env-file .env.local \\
      -f compose.yaml -f compose.$app_env.yaml up -d --wait

MSG
