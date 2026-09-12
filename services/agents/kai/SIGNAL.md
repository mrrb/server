# Signal support

Blocked on: **a real phone number for registration** (Signal rejects most VoIP numbers)

## 1. Network - root `docker-compose.yml`

Needs egress (Signal servers), so it is NOT `internal: true`:

```yaml
  agent-kai-signal:
    ipam:
      config:
        - subnet: 172.24.0.0/16
```

(Do NOT add it to adminer, the JSON-RPC interface is unauthenticated.)

## 2. Service - `docker-compose.nanobot.yml`

Append after the sandbox service:

```yaml
  nanobot-kai-signal:
    image: bbernhard/signal-cli-rest-api:${AGENT_KAI_SIGNAL_IMAGE_VERSION:-latest}
    restart: unless-stopped
    platform: ${PLATFORM_ARCH:-linux/amd64}
    container_name: nanobot-kai-signal

    environment:
      MODE: 'json-rpc'

    healthcheck:
      test:
        - CMD-SHELL
        - 'echo > /dev/tcp/127.0.0.1/8080 || exit 1'
      start_period: 60s
      interval: 30s
      timeout: 10s
      retries: 5

    networks:
      - agent-kai-signal

    volumes:
      - './services/agents/kai/signal/:/home/.signal-cli'

    mem_limit: 1g
    cpus: '0.5'
    pids_limit: 128
    security_opt:
      - no-new-privileges:true

    labels:
      ## Traefik
      traefik.enable: false
```

Add `- agent-kai-signal` to the `nanobot-kai` service networks too.
(No `cap_drop`, third-party image; no chown, it runs as root.)

## 3. `env.json`

```json
  "AGENT_KAI_SIGNAL_IMAGE_VERSION": "",
```

and extend `NANOBOT_CHANNELS`: `telegram,whatsapp,signal` (signal-cli deps get baked into the image build).

## 4. Directories + files

```sh
mkdir -p services/agents/kai/signal
printf '*\n!.gitignore\n' > services/agents/kai/signal/.gitignore
```

`server_nanobot_chk_fix` (server.sh): add
`_check_create_dir $_SERVICESPATH/agents/kai/signal/` (no chown, root container).

## 5. Config - `config.json` (see README recommended block)

```json
"ssrfWhitelist": ["172.22.0.0/16", "172.23.0.0/16", "172.24.0.0/16"],
"channels": {
  "signal": {
    "enabled": true,
    "phoneNumber": "+34XXXXXXXXX",
    "daemonHost": "nanobot-kai-signal",
    "daemonPort": 8080,
    "dm": { "enabled": true, "policy": "allowlist" },
    "group": { "enabled": true, "policy": "allowlist", "requireMention": true }
  }
}
```

## 6. Registration + deploy

```sh
server_build nanobot-kai nanobot-kai-signal && server_up
# captcha from https://signalcaptchas.org/challenge/generate.html
server_compose exec nanobot-kai-signal signal-cli -u +34XXXXXXXXX register --captcha <TOKEN>
server_compose exec nanobot-kai-signal signal-cli -u +34XXXXXXXXX verify <CODE>
server_compose restart nanobot-kai-signal
```

Account state persists in `services/agents/kai/signal/`.

## Notes

* Resources: JVM daemon, ~150–300 MB RAM idle (cap 1g / 0.5 CPU / 128 pids), ~600 MB image; disk grows slowly with received attachments.
* The daemon's JSON-RPC is unauthenticated, the dedicated network keeps it private; never add it to `server` or route it through Traefik.
* Watchtower manages this image normally (claimed upstream namespace), unlike the locally built nanobot/sandbox images.
* `ssrfWhitelist` must include `172.24.0.0/16` (nanobot's SSRF guard otherwise blocks the internal daemon call).
