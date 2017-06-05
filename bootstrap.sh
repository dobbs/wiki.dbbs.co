#!/bin/bash -eu
set -o pipefail

readonly COMPOSE_DIR=$( cd $(dirname $0); pwd )

main() {
    create-droplet
    create-droplet-floating-ip
    create-fqdn
    create-wildcard-cname

    create-docker-environment
    create-named-volumes
    open-portal-to-named-volumes
    install-configs-in-named-volumes
    close-portal-to-named-volumes
}

create-environment() {
    source $COMPOSE_DIR/.env
    [ -n "${DROPLET:-}" ]    || { echo ".env missing DROPLET" ; FATAL=1; }
    [ -n "${TOKEN_FILE:-}" ] || { echo ".env missing TOKEN_FILE" ; FATAL=1; }
    [ -n "${REGION:-}" ]     || { echo ".env missing REGION" ; FATAL=1; }

    [ -z "${FATAL:-}" ] || exit 1
}

create-droplet() {
    droplet-exists || {
        docker-machine \
            create --driver digitalocean\
            --digitalocean-access-token=$(token) \
            --digitalocean-region=$REGION \
            $DROPLET
    }
}

create-droplet-floating-ip() {
    local IP=$(droplet-floating-ip)
    [ -n "$IP" ] || {
        local ID=$(droplet-list | awk "/$DROPLET\$/ {print \$1}")
        do-api -sS -X POST \
               -d "{\"droplet_id\":$ID}" \
               "https://api.digitalocean.com/v2/floating_ips"
    }
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
           -v wiki.$DROPLET:/dot-wiki \
           buildpack-deps:jessie-curl ping -i 60 localhost
}

install-configs-in-named-volumes() {
    cd $COMPOSE_DIR
    docker cp dot-wiki/config.json ping:/dot-wiki/config.json
    docker cp proxy/Caddyfile ping:/proxy/Caddyfile
    docker-compose run --rm --user root web chown -R app:app .wiki
}

close-portal-to-named-volumes() {
    docker rm -f ping
}

create-fqdn() {
    fqdn-exists || {
        do-api -X POST \
               -d "{\"name\":\"${DROPLET}\",\"ip_address\":$(droplet-floating-ip)}" \
               "https://api.digitalocean.com/v2/domains"
    }
}

create-wildcard-cname() {
    wildcard-cname-exists || {
        do-api -X POST \
               -d "{\"type\":\"CNAME\",\"name\":\"*\",\"data\":\"@\",\"priority\":null,\"port\":null,\"weight\":null}" \
               "https://api.digitalocean.com/v2/domains/${DROPLET}/records"
    }
}

droplet-list-json() {
    do-api -sS -X GET "https://api.digitalocean.com/v2/droplets?page=1&per_page=10"
}

droplet-list() {
    # memoize to self-regulate DO rate-limits
    if [ -z "${DROPLET_LIST:-}" ]; then
        local JSON="$(droplet-list-json)"
        echo $JSON
        <<<"$JSON" jq -r '.droplets[]'
        readonly DROPLET_LIST="$(<<<"$JSON" jq -r '.droplets[] | .id, .name' \
            | paste - -)"
    fi
    echo -e $DROPLET_LIST
}

droplet-exists() {
    droplet-list | grep -q "$DROPLET\$"
}

droplet-floating-ip() {
    do-api -sS -X GET "https://api.digitalocean.com/v2/floating_ips?page=1&per_page=20" \
        | jq ".floating_ips[] | select(.droplet.name == \"$DROPLET\") | .ip"
}

fqdn-exists() {
    # not_found is in the error payload if the domain doesn't exist
    # so this code is a double-negative: true if we don't find "not_found"
    do-api -sS -X GET "https://api.digitalocean.com/v2/domains/${DROPLET}" \
        | grep -qv not_found
}

wildcard-cname-exists() {
    do-api -sS -X GET \
           "https://api.digitalocean.com/v2/domains/${DROPLET}/records" \
        | jq -r '.domain_records[] | select(.type == "CNAME") | .name, .data' \
        | paste - - \
        | grep -q '^*'
}

do-api() {
    curl \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $(token)" \
        $@
}

token() {
    cat $TOKEN_FILE
}

case ${1:-} in
    create-droplet|create-droplet-floating-ip|create-fqdn|create-wildcard-cname|wildcard-cname-exists)
        readonly CMD=${1}
        shift
    ;;
    *)
        readonly CMD=main
    ;;
esac

create-environment $@
$CMD
