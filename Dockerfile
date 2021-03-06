FROM golang:alpine as pre-build

ARG version="0.11.1"
ARG plugins="git,cors,realip,expires,cache"

COPY builder.sh /usr/bin/builder.sh

RUN apk add --update --no-cache git gcc musl-dev && \
	VERSION=${version} PLUGINS=${plugins} /bin/sh /usr/bin/builder.sh

# official
FROM alpine:3.8

ENV CADDYPATH /app/cert

RUN apk add --no-cache openssh-client git tzdata

# install caddy
COPY --from=pre-build /install/caddy /usr/bin/caddy
COPY Caddyfile /app/caddy/Caddyfile

RUN /usr/bin/caddy -version
RUN /usr/bin/caddy -plugins

WORKDIR /app

ENTRYPOINT ["caddy"]
CMD ["--conf", "/app/caddy/Caddyfile", "--log", "/app/logs/caddy.log", "--agree=true", "-root=/app/www"]