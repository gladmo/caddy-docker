FROM golang:alpine as pre-build

ARG version="0.11.1"
ARG plugins="git,cors,realip,expires,cache"

COPY builder.sh /usr/bin/builder.sh

RUN apk add --update --no-cache git gcc musl-dev && \
	VERSION=${version} PLUGINS=${plugins} /bin/sh /usr/bin/builder.sh

# official
FROM alpine:3.8

# Let's Encrypt Agreement
ENV ACME_AGREE="true"

RUN apk add --no-cache openssh-client git

# install caddy
COPY --from=builder /install/caddy /usr/bin/caddy
COPY Caddyfile /etc/Caddyfile

RUN /usr/bin/caddy -version
RUN /usr/bin/caddy -plugins

WORKDIR /app

ENTRYPOINT ["caddy"]
CMD ["--conf", "/etc/Caddyfile", "--log", "stdout", "--agree=$ACME_AGREE", "-root=/app"]