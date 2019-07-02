# Default goals definition
.DEFAULT_GOAL := _fail

VIRTUALENV_DIR := .venv
DOCKER_COMPOSE := docker-compose --project-directory ${CURDIR}/pi-gen --file ${CURDIR}/pi-gen/docker-compose.yml --project-name pi_gen

ifndef PYTHON_VERSION
PYTHON_VERSION := python3.7
endif

.PHONY: _fail
_fail:
	echo Defult targets are not supported. This is the content of the targeted Makefile
	cat $(lastword ${MAKEFILE_LIST})
	@false

${VIRTUALENV_DIR}:
	virtualenv --python ${PYTHON_VERSION} ${VIRTUALENV_DIR}
	${VIRTUALENV_DIR}/bin/pip install docker-compose pre-commit

.git/hooks/pre-commit: ${VIRTUALENV_DIR}
	${VIRTUALENV_DIR}/bin/pre-commit install -f --install-hooks

.PHONY: install-hooks
install-hooks: .git/hooks/pre-commit
	@true

.PHONY: init-submodules
init-submodules:
	git submodule update --init --recursive

.PHONY: bump-submodules
bump-submodules:
	bash ${CURDIR}/.scripts/bump-all-submodules.sh

.PHONY: development
development: install-hooks init-submodules
	@true

.PHONY: start-apt-cacher
start-apt-cacher:
	${DOCKER_COMPOSE} up --detach

.PHONY: stop-apt-cacher
stop-apt-cacher:
	${DOCKER_COMPOSE} down

.PHONY: create-default-image
create-default-image: export TMP_FILE := $(shell mktemp --tmpdir=/tmp)
create-default-image:
	${MAKE} start-apt-cacher || true
	echo "Config"
	echo "IMG_NAME=Raspbian" >> ${TMP_FILE}
	echo "DEPLOY_ZIP=0" >> ${TMP_FILE}
	echo "DEPLOY_DIR=${CURDIR}/images" >> ${TMP_FILE}
	echo "FIRST_USER_NAME=${USER}" >> ${TMP_FILE}
	echo "FIRST_USER_PASSWORD=password" >> ${TMP_FILE}
	echo "APT_CACHE=$(shell ${DOCKER_COMPOSE} ps -q apt-cacher-ng | xargs --no-run-if-empty docker inspect --format='{{.NetworkSettings.Networks.pi_gen_default.IPAddress}}:3142')" >> ${TMP_FILE}
	bash -x ${CURDIR}/pi-gen/build-docker.sh -c ${TMP_FILE}
	@${MAKE} start-apt-cacher
