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
    docker volume create --name proxy.d.$DROPLET
    docker volume create --name proxy.certs.$DROPLET
    docker volume create --name wiki.$DROPLET
}

open-portal-to-named-volumes() {
    docker run \
           --name portal \
           -d \
           --init=true \
           -v proxy.$DROPLET:/proxy \
           -v proxy.d.$DROPLET:/proxy.d \
           -v proxy.certs.$DROPLET:/proxy.certs \
           --user=root \
           --entrypoint=/usr/bin/tail \
           dobbs/proxy:0.10.10 \
           -f /dev/null
}

install-configs-in-named-volumes() {
    cd $COMPOSE_DIR
    docker cp Caddyfile portal:/proxy/Caddyfile
    docker exec portal \
           sh -c 'chown -R caddy:nogroup /proxy /proxy.d /proxy.certs'
    docker-compose run --rm --user root farm chown -R app:app .wiki
}

close-portal-to-named-volumes() {
    docker stop portal
    docker rm portal
}

create-environment $@
main
