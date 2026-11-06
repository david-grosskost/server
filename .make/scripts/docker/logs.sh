#!/usr/bin/env bash
# Shows the log of the weekly clean-ups (systemd journal), and the next run.
#
# @usage make docker@logs
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

run systemctl list-timers "$DOCKER_UNIT.timer" --no-pager
run journalctl -u "$DOCKER_UNIT.service" --no-pager -n 100
