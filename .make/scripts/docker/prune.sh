#!/usr/bin/env bash
# Removes the Docker images nobody needs any more: for each image repository
# (ghcr.io/…/suitecrm-core, mariadb…), keeps the DOCKER_KEEP most recent tags
# (2: the version in service and the previous one, for a rollback) and every
# image a container uses, running or stopped; then the untagged images and
# the build cache. Never touches containers, volumes or /srv.
# DRY_RUN=1 lists what would be removed, without removing it.
#
# @usage make docker@prune [DRY_RUN=1] [DOCKER_KEEP=2]
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

[[ $DOCKER_KEEP =~ ^[1-9][0-9]*$ ]] || die "docker@prune : DOCKER_KEEP doit être un nombre ≥ 1 (reçu « $DOCKER_KEEP »)"
dry="${DRY_RUN:-0}"

used_by_containers () {
  docker ps -a --format '{{.Image}}' | sort -u \
    | xargs -r docker image inspect --format '{{.Id}}' 2>/dev/null | sort -u
}

printf '\n  Nettoyage des images Docker (%s)%s\n\n' "$(date '+%F %T')" "$([ "$dry" = 1 ] && echo ', simulation')"
df -h / | awk 'NR == 2 { print "  Disque avant : " $3 " utilisés, " $4 " libres" }'

used="$(used_by_containers)"
removed=0

# One line per tag: repository, tag, image id, creation date (sortable).
while IFS=$'\t' read -r repository; do
  rank=0
  while IFS=$'\t' read -r _created tag id; do
    rank=$((rank + 1))
    if [ "$rank" -le "$DOCKER_KEEP" ]; then
      info "garde   $repository:$tag"
    elif grep -qx "$id" <<< "$used"; then
      info "garde   $repository:$tag (utilisée par un conteneur)"
    elif [ "$dry" = 1 ]; then
      info "retire  $repository:$tag (simulation)"
      removed=$((removed + 1))
    else
      docker rmi "$repository:$tag" >/dev/null && info "retire  $repository:$tag"
      removed=$((removed + 1))
    fi
  done < <(docker images --no-trunc "$repository" --format '{{.CreatedAt}}\t{{.Tag}}\t{{.ID}}' \
    | grep -v $'\t<none>\t' | sort -r)
done < <(docker images --format '{{.Repository}}' | grep -vx '<none>' | sort -u)

if [ "$dry" != 1 ]; then
  # Untagged images (left by updates) and the build cache (nothing is built here).
  docker image prune -f >/dev/null
  docker builder prune -f >/dev/null
fi

df -h / | awk 'NR == 2 { print "  Disque après : " $3 " utilisés, " $4 " libres" }'
info "$removed image(s) $([ "$dry" = 1 ] && echo 'à retirer' || echo 'retirée(s)'), plus les images sans nom et le cache de build."
