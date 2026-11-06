# docker: clean-up of the Docker images nobody needs, see docs/docker.md.

DOCKER_SCRIPTS := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))/scripts

# make docker@prune DRY_RUN=1: lists, removes nothing.
DRY_RUN ?= 0
export DRY_RUN

.PHONY: docker@prune docker@schedule docker@logs

docker@prune:
	@$(DOCKER_SCRIPTS)/docker/prune.sh

docker@schedule:
	@$(DOCKER_SCRIPTS)/docker/schedule.sh

docker@logs:
	@$(DOCKER_SCRIPTS)/docker/logs.sh
