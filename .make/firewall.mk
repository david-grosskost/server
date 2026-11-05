# firewall: outgoing SMTP refused to the containers, except smtp-out (the prod
# instances), see docs/pare-feu.md.

FIREWALL_SCRIPTS := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))/scripts

.PHONY: firewall@install firewall@status firewall@test

firewall@install:
	@$(FIREWALL_SCRIPTS)/firewall/install.sh

firewall@status:
	@$(FIREWALL_SCRIPTS)/firewall/status.sh

firewall@test:
	@$(FIREWALL_SCRIPTS)/firewall/test.sh
