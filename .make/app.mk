# app: installation of the server's administration, in one command.

APP_SCRIPTS := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))/scripts

.PHONY: app@install

app@install:
	@$(APP_SCRIPTS)/app/install.sh
