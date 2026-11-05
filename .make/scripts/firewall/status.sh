#!/usr/bin/env bash
# Shows the outgoing SMTP firewall: its service, its rules, and the containers
# allowed to send (members of the smtp-out network).
#
# @usage make firewall@status
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

run systemctl status "$FIREWALL_UNIT.service" --no-pager --lines=5 || true
run sudo iptables -S DOCKER-USER
if sudo ip6tables -S DOCKER-USER >/dev/null 2>&1; then
  run sudo ip6tables -S DOCKER-USER
fi
if docker network inspect "$FIREWALL_NETWORK" >/dev/null 2>&1; then
  info "Conteneurs autorisés à envoyer ($FIREWALL_NETWORK) :"
  docker network inspect "$FIREWALL_NETWORK" \
    -f '{{range .Containers}}    {{.Name}} {{.IPv4Address}}{{"\n"}}{{else}}    aucun{{"\n"}}{{end}}'
else
  info "Réseau $FIREWALL_NETWORK absent : make firewall@install"
fi
