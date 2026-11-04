# backup: restic backups of the server (/srv), see docs/sauvegardes.md.

BACKUP_SCRIPTS := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))/scripts

.PHONY: backup@init backup@run backup@snapshots backup@schedule backup@logs backup@restore

backup@init:
	@$(BACKUP_SCRIPTS)/backup/init.sh

backup@run:
	@$(BACKUP_SCRIPTS)/backup/run.sh

backup@snapshots:
	@$(BACKUP_SCRIPTS)/backup/snapshots.sh

backup@schedule:
	@$(BACKUP_SCRIPTS)/backup/schedule.sh

backup@logs:
	@$(BACKUP_SCRIPTS)/backup/logs.sh

backup@restore:
	@$(BACKUP_SCRIPTS)/backup/restore.sh
