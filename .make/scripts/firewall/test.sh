#!/usr/bin/env bash
# Checks the outgoing SMTP firewall from two throwaway containers, against a
# public mail server (FIREWALL_TEST_HOST:FIREWALL_TEST_PORT, smtp.gmail.com:587
# by default): refused from Docker's default network, as for a demo, reached
# from smtp-out, as for a prod. Only opens the connection: no email is sent.
#
# @usage make firewall@test
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

target="$FIREWALL_TEST_HOST:$FIREWALL_TEST_PORT"

# Prints the greeting of the mail server (220 …), empty if not reached.
#
# @param string $@ Extra docker run arguments (e.g. the network)
greeting () {
  docker run --rm "$@" "$FIREWALL_TEST_IMAGE" \
    timeout 10 nc "$FIREWALL_TEST_HOST" "$FIREWALL_TEST_PORT" </dev/null 2>/dev/null \
    | tr -d '\r' | grep -m1 '^220' || true
}

failed=0

info "Réseau par défaut (comme une démo) → $target : doit être refusé"
answer="$(greeting)"
if [ -z "$answer" ]; then
  info "  ✔ refusé"
else
  info "  ✘ joignable : « $answer »"
  failed=1
fi

info "Réseau $FIREWALL_NETWORK (comme une prod) → $target : doit répondre"
answer="$(greeting --network "$FIREWALL_NETWORK")"
if [ -n "$answer" ]; then
  info "  ✔ joignable : « $answer »"
else
  info "  ✘ refusé : le serveur de test est-il en panne ? (FIREWALL_TEST_HOST=…)"
  failed=1
fi

[ "$failed" = 0 ] || die "firewall@test : échec"
info "Pare-feu SMTP conforme."
