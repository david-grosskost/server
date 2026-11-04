#!/usr/bin/env bash
# Lists the snapshots of the restic repository, then its size on disk.
#
# @usage make backup@snapshots
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

restic_run snapshots
restic_run stats --mode raw-data
