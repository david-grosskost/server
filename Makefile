# Convention: make <domain>@<action> runs .make/scripts/<domain>/<action>.sh
# Each .make/<domain>.mk only declares targets; the logic lives in the scripts.

# Must be set before any include, otherwise make defaults to the first target.
.DEFAULT_GOAL := .list

include $(wildcard .make/*.mk)

# Lists every <domain>@<action> target declared in a .PHONY line.
.PHONY: .list

.list:
	@printf '\n  \033[1;35m%s\033[0m - commandes disponibles\n' "$(notdir $(CURDIR))"
	@grep -h '^\.PHONY:' $(MAKEFILE_LIST) \
		| sed 's/^\.PHONY: *//' | tr ' ' '\n' | grep '@' | sort -u \
		| awk -F'@' '{ \
			if ($$1 != last) { printf "\n  \033[1;33m%s\033[0m\n", $$1; last = $$1 } \
			printf "    \033[36m%s\033[0m\n", $$0 \
		}'
	@printf '\n'
