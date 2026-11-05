#!/usr/bin/env bash
# Applies the outgoing SMTP firewall: creates the smtp-out network if needed,
# then replaces our rules in Docker's DOCKER-USER chain (IPv4, and IPv6 when
# Docker uses it). Containers of smtp-out reach the SMTP ports, every other
# container is refused them (connection reset at once, no timeout).
# Run as root, by the srv-firewall service after each start of Docker (rules
# are lost at reboot): make firewall@install sets it up. Safe to run again.
#
# @usage sudo .make/scripts/firewall/apply.sh [--remove]
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

[ "$(id -u)" = 0 ] || die "firewall : à lancer en root (make firewall@install)"

# Removes our rules from DOCKER-USER, whatever their number.
#
# @param string $1 iptables or ip6tables
remove_rules () {
  local rule args
  while read -r rule; do
    read -ra args <<< "${rule/#-A/-D}"
    "$1" "${args[@]}"
  done < <("$1" -S DOCKER-USER | grep -e "--comment $FIREWALL_TAG" || true)
}

# Adds our rules at the top of DOCKER-USER: smtp-out first (allowed, goes on
# to Docker's own rules), then everything else coming from a container
# (refused). Only traffic leaving the containers: their bridges are docker0
# and br-*. A server publishing port 25 to receive emails is not affected.
#
# @param string $1 iptables or ip6tables
# @param string $2 Allowed source (the smtp-out subnet), empty for none
add_rules () {
  local iface match=(-p tcp -m multiport --dports "$FIREWALL_SMTP_PORTS" -m comment --comment "$FIREWALL_TAG")
  for iface in docker0 br-+; do
    "$1" -I DOCKER-USER 1 -i "$iface" "${match[@]}" -j REJECT --reject-with tcp-reset
  done
  if [ -n "$2" ]; then
    "$1" -I DOCKER-USER 1 -s "$2" "${match[@]}" -j RETURN
  fi
}

iptables -S DOCKER-USER >/dev/null 2>&1 \
  || die "firewall : chaîne DOCKER-USER absente (Docker démarré ?)"

remove_rules iptables
if ip6tables -S DOCKER-USER >/dev/null 2>&1; then
  remove_rules ip6tables
  ipv6=1
else
  ipv6=0
fi

if [ "${1:-}" = --remove ]; then
  info "Pare-feu SMTP retiré : les conteneurs peuvent de nouveau tous envoyer."
  exit 0
fi

# The network the prod instances join (external in their compose.prod.yaml).
if ! docker network inspect "$FIREWALL_NETWORK" >/dev/null 2>&1; then
  docker network create --driver bridge --subnet "$FIREWALL_SUBNET" \
    --opt com.docker.network.bridge.name="br-$FIREWALL_NETWORK" "$FIREWALL_NETWORK" >/dev/null
  info "Réseau $FIREWALL_NETWORK créé ($FIREWALL_SUBNET)."
fi
subnet="$(docker network inspect "$FIREWALL_NETWORK" -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}')"
case " $subnet " in
  *" $FIREWALL_SUBNET "*) ;;
  *) die "firewall : le réseau $FIREWALL_NETWORK a la plage « $subnet », pas $FIREWALL_SUBNET" ;;
esac

add_rules iptables "$FIREWALL_SUBNET"
# No IPv6 range on smtp-out: in IPv6, every container is refused.
if [ "$ipv6" = 1 ]; then
  add_rules ip6tables ""
fi

info "Pare-feu SMTP appliqué : ports $FIREWALL_SMTP_PORTS refusés aux conteneurs, sauf $FIREWALL_NETWORK."
