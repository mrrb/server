# xray

[https://github.com/xtls/xray-core](https://github.com/xtls/xray-core)

Authenticated web proxy (`ghcr.io/xtls/xray-core`) for personal use from networks where direct traffic is undesirable or blocked. TLS is terminated by Traefik (SNI dispatch on `websecure`, no extra ports); xray speaks plain HTTP internally, requires Basic auth, tunnels all public destinations (`freedom` outbound) and blackholes private ranges (`geoip:private`) so the proxy can't pivot into the docker network.

```
client -> TLS -> Traefik :443 [SNI]
                    └-> xray :8080 (user/pass) -> anywhere public on the internet
```

## Setup

1. Point the DNS record `${XRAY_HOST}` to the VPS IP.
2. Set `XRAY_USER` and `XRAY_PASSWORD` in `env.extra.json` (`openssl rand -hex 16` for both — hex is URL-safe, required for proxy URLs). Keep credentials secret: anyone holding them can use the VPS as their egress IP.
3. `sudo bash -c 'source /srv/server/server.sh && gen_server_env && server_compose up -d'`.

`config/xray.json.in` is rendered into `config/xray.json` by `gen_xray_config` (called from `server_init`); the rendered file contains the credentials and is gitignored.

## Usage - HTTPS_PROXY / curl

```sh
export XRAY_USER=... XRAY_PASSWORD=...                                                                # export from a chmod 600 file, not shell history
curl -x "https://$XRAY_USER:$XRAY_PASSWORD@proxy.server.tld:443" https://openrouter.ai/api/v1/models  # 200
curl -x "https://$XRAY_USER:$XRAY_PASSWORD@proxy.server.tld:443" https://example.com                  # 200
curl -x "https://$XRAY_USER:$XRAY_PASSWORD@proxy.server.tld:443" https://10.0.0.1/                    # blocked (connection dropped)
```

```sh
export HTTPS_PROXY="https://$XRAY_USER:$XRAY_PASSWORD@proxy.server.tld:443"
export NO_PROXY="localhost,127.0.0.1,.internal.company.com" # keep corp-internal hosts direct
```

## Changing the routing

Private ranges are blocked first (`geoip:private` -> `blackhole`), everything else goes to `freedom`. To restrict destinations further (e.g. an API-domain allowlist), add a `domain:` rule before the inbound rule in `config/xray.json.in`, then `gen_xray_config && server_compose up -d webproxy`.
