#!/bin/bash
set -xeuo pipefail
IFS=$'\t\n\r'

readonly COMPOSE_DIR=$( cd $(dirname $0); pwd )

main() {
    create-environment $@
    copy-certs-to-new-home
}

create-environment() {
    source $COMPOSE_DIR/.env
    [ -n "${DROPLET:-}" ]    || { echo ".env missing DROPLET" ; exit 1; }

    eval $(docker-machine env $DROPLET)
}

copy-certs-to-new-home() {
    docker run \
           --rm \
           -v proxy.$DROPLET:/proxy \
           -v proxy.d.$DROPLET:/proxy.d \
           -v proxy.certs.$DROPLET:/proxy.certs \
           --entrypoint=/bin/sh \
           dobbs/proxy:0.10.10 \
           -c '\
cp -Rp /proxy/acme /proxy.certs/acme;\
cp -Rp /proxy/ocsp /proxy.certs/ocsp;'
}

main $@
