#!/bin/bash
set -euo pipefail
IFS=$'\t\n\r'

readonly COMPOSE_DIR=$( cd $(dirname $0); pwd )

main() {
    create-docker-environment
    create-named-volumes
    open-portal-to-named-volumes
    install-configs-in-named-volumes
    close-portal-to-named-volumes
}

create-environment() {
    source $COMPOSE_DIR/.env
    [ -n "${DROPLET:-}" ]    || { echo ".env missing DROPLET" ; FATAL=1; }

    [ -z "${FATAL:-}" ] || exit 1
}

create-docker-environment() {
    eval $(docker-machine env $DROPLET)
}

create-named-volumes() {
    docker volume create --name proxy.$DROPLET
    docker volume create --name wiki.$DROPLET
}

open-portal-to-named-volumes() {
    docker run --name ping -d \
           -v proxy.$DROPLET:/proxy \
           buildpack-deps:jessie-curl ping -i 60 localhost
}

install-configs-in-named-volumes() {
    cd $COMPOSE_DIR
    docker cp proxy/Caddyfile ping:/proxy/Caddyfile
    docker-compose run --rm --user root web chown -R app:app .wiki
}

close-portal-to-named-volumes() {
    docker rm -f ping
}

create-environment $@
main
