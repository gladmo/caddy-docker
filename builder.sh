#!/bin/sh

VERSION=${VERSION:-"0.11.1"}
TELEMETRY=${ENABLE_TELEMETRY:-"true"}

# caddy
git clone https://github.com/mholt/caddy -b "v$VERSION" /go/src/github.com/mholt/caddy \
    && cd /go/src/github.com/mholt/caddy \
    && git checkout -b "v$VERSION"

# plugin helper
GOOS=linux GOARCH=amd64 go get -v github.com/abiosoft/caddyplug/caddyplug
alias caddyplug='GOOS=linux GOARCH=amd64 caddyplug'

# telemetry
run_file="/go/src/github.com/mholt/caddy/caddy/caddymain/run.go"
if [ "$TELEMETRY" = "false" ]; then
    cat > "$run_file.disablestats.go" <<EOF
    package caddymain
    import "os"
    func init() {
        switch os.Getenv("ENABLE_TELEMETRY") {
        case "0", "false":
            EnableTelemetry = false
        case "1", "true":
            EnableTelemetry = true
        }
    }
EOF
fi

# alidns
# when pr merge, remove this
mkdir /go/src/github.com/caddyserver/dnsproviders/alidns
cat /go/src/github.com/caddyserver/dnsproviders/alidns/alidns.go <<EOF
// alidns
package alidns

import (
    "errors"

    "github.com/mholt/caddy/caddytls"
    "github.com/xenolf/lego/providers/dns/alidns"
)

func init() {
    caddytls.RegisterDNSProvider("alidns", NewDNSProvider)
}

// NewDNSProvider returns a new alidns DNS challenge provider.
// The credentials are interpreted as follows:
//
// len(0): use credentials from environment
// len(2): credentials[0] = API key
//         credentials[1] = Secret key
func NewDNSProvider(credentials ...string) (caddytls.ChallengeProvider, error) {
    switch len(credentials) {
    case 0:
        return alidns.NewDNSProvider()
    case 2:
        config := alidns.NewDefaultConfig()
        config.APIKey = credentials[0]
        config.SecretKey = credentials[1]
        return alidns.NewDNSProviderConfig(config)
    default:
        return nil, errors.New("invalid credentials length")
    }
}
EOF

cat /go/src/github.com/caddyserver/dnsproviders/alidns.go <<EOF
import _ "github.com/mholt/caddy/caddytls/alidns"
EOF

# plugins
for plugin in $(echo $PLUGINS | tr "," " "); do \
    go get -v $(caddyplug package $plugin); \
    printf "package caddyhttp\nimport _ \"$(caddyplug package $plugin)\"" > \
        /go/src/github.com/mholt/caddy/caddyhttp/$plugin.go ; \
    done

# builder dependency
git clone https://github.com/caddyserver/builds /go/src/github.com/caddyserver/builds

# build
cd /go/src/github.com/mholt/caddy/caddy \
    && GOOS=linux GOARCH=amd64 go run build.go -goos=$GOOS -goarch=$GOARCH -goarm=$GOARM \
    && mkdir -p /install \
    && mv caddy /install
