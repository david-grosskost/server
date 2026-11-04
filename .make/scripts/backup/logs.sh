#!/usr/bin/env bash
# Shows the log of the nightly backups (systemd journal), and the next run.
#
# @usage make backup@logs
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

run systemctl list-timers "$BACKUP_UNIT.timer" --no-pager
run journalctl -u "$BACKUP_UNIT.service" --no-pager -n 100
