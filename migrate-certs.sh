#!/bin/bash
set -xeuo pipefail
IFS=$'\t\n\r'

readonly COMPOSE_DIR=$( cd $(dirname $0); pwd )

main() {
    create-environment $@
    remove-certs-from-old-home
}

create-environment() {
    source $COMPOSE_DIR/.env
    [ -n "${DROPLET:-}" ]    || { echo ".env missing DROPLET" ; exit 1; }

    eval $(docker-machine env $DROPLET)
}

remove-certs-from-old-home() {
    docker run \
           --rm \
           -v proxy.$DROPLET:/proxy \
           -v proxy.d.$DROPLET:/proxy.d \
           -v proxy.certs.$DROPLET:/proxy.certs \
           --entrypoint=/bin/sh \
           dobbs/proxy:0.10.10 \
           -c 'rm -rf /proxy/acme /proxy/ocsp'
}

main $@
