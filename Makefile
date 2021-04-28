# Adheres to [Semantic Versioning](https://semver.org)
VERSION := 1.0.0

IMAGE := mpd
SERVICE := mpd
USER := mpd

BUILD_CONTEXT := .
DOCKERFILE := $(BUILD_CONTEXT)/Dockerfile
DOCKERCOMPFILE := $(BUILD_CONTEXT)/docker-compose.yml

.PHONY: help tag prepare-deploy config-template-vanilla run-shell up start \
	stop down destroy restart ps log login-shell login-shell-root \
	update-database show-status add-music toggle-music clean

# Default target
help:
	@echo "Available targets:"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null \
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ \
		{if ($$1 !~ "^[#.]") {print $$1}}' \
	| sort \
	| egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

build: $(DOCKERFILE) .dockerignore mpd.conf.template start.sh
	@echo "Dummy time stamp file for Make to determine when to rebuild" > $@
	sudo docker build -t $(IMAGE):$(VERSION) $(BUILD_CONTEXT)/ \
		-f $(DOCKERFILE)
	sudo docker image tag $(IMAGE):$(VERSION) $(IMAGE):latest

tag:
# If variable `t` is not defined, use `$(VERSION)`
ifeq ($(origin t),undefined)
	@echo "Make:  No tag provided, \`$(VERSION)\` is used as default."
	@echo "Make:      You can provide a custom tag via variable \`t\`"
	@echo "Make:      (\`make $@ t=<TAG>\`)."
	sudo docker image tag $(IMAGE):latest $(IMAGE):$(VERSION)
else
	sudo docker image tag $(IMAGE):latest $(IMAGE):$(t)
endif

prepare-deploy:
	mkdir -p $(BUILD_CONTEXT)/$(SERVICE)/mpd/playlists/
	mkdir -p $(BUILD_CONTEXT)/$(SERVICE)/music/
# If `docker-compose.yml` does not exist, copy the template
ifeq (,$(wildcard $(DOCKERCOMPFILE)))
	cp $(DOCKERCOMPFILE).template $(DOCKERCOMPFILE)
endif
# If `./mpd/mpd.conf` does not exist, copy the template
ifeq (,$(wildcard $(BUILD_CONTEXT)/$(SERVICE)/mpd.conf))
	cp $(BUILD_CONTEXT)/mpd.conf.template $(BUILD_CONTEXT)/$(SERVICE)/mpd.conf
endif
	$(MAKE) config-template-vanilla
	@echo "Make:  Customize configuration files \`$(DOCKERCOMPFILE)\` and"
	@echo "Make:      \`$(BUILD_CONTEXT)/$(SERVICE)/mpd.conf\` and then"
	@echo "Make:      deploy (using \`make deploy\`)."

config-template-vanilla:
# `chown` not needed, `cat`’s STDOUT redirection is outside the `sudo` scope
	sudo docker run --rm $(IMAGE):latest \
		cat /etc/mpd.conf > \
		$(BUILD_CONTEXT)/$(SERVICE)/mpd.conf.template-vanilla

run-shell:
	sudo docker-compose run $(SERVICE) ash

deploy: up
up:
	sudo docker-compose -f $(DOCKERCOMPFILE) up -d

start:
	sudo docker-compose -f $(DOCKERCOMPFILE) start

stop:
	sudo docker-compose -f $(DOCKERCOMPFILE) stop

down:
	sudo docker-compose -f $(DOCKERCOMPFILE) down

destroy:
	sudo docker-compose -f $(DOCKERCOMPFILE) down -v

restart:
	sudo docker-compose -f $(DOCKERCOMPFILE) stop
	sudo docker-compose -f $(DOCKERCOMPFILE) up -d

ps:
	sudo docker-compose -f $(DOCKERCOMPFILE) ps

log:
	sudo docker logs -t -f $(SERVICE)

login-shell:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) ash

login-shell-root:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec $(SERVICE) ash

update-database:
# If variable `m` is not defined, print information and perform full MPD
# database update
ifeq ($(origin m),undefined)
	@echo "Make:  No path provided, full MPD database update is performed"
	@echo "Make:      by default.  You can do partial updates by providing"
	@echo "Make:      a custom music path via variable \`m\`"
	@echo "Make:      (\`make $@ m=<MUSIC_PATH>\`)."
endif
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) \
		mpc update $(m)

show-status:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) \
		mpc status

add-music:
# Only continue if variable `m` is defined
ifeq ($(origin m),undefined)
	@echo "Make:  Please provide a music path via variable \`m\`"
	@echo "Make:      (\`make $@ m=<MUSIC_PATH>\`)."
else
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) \
		mpc add $(m)
endif

toggle-music:
	sudo docker-compose -f $(DOCKERCOMPFILE) exec -u $(USER) $(SERVICE) \
		mpc toggle

clean:
	rm -rf $(BUILD_CONTEXT)/build
# Confirm before removal since data might be deleted
	@echo "Make:  !CAUTION!  The following will delete the configuration"
	@echo "Make:      file \`$(DOCKERCOMPFILE)\` and the directory"
	@echo "Make:      \`$(BUILD_CONTEXT)/$(SERVICE)/\` where all data is"
	@echo "Make:      stored.  Please confirm."
	rm -rI \
		$(DOCKERCOMPFILE) \
		$(BUILD_CONTEXT)/$(SERVICE)/
