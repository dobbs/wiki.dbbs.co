FROM abiosoft/caddy:0.10.2

RUN apk add --no-cache libcap
RUN setcap 'cap_net_bind_service=+ep' /usr/bin/caddy \
 && addgroup -S -g 8888 caddy \
 && adduser -S -u 8888 -D -H caddy \
 && mkdir -p /etc/proxy

VOLUME /etc/proxy

USER caddy
