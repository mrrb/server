# Kai - Nanobot AI agent

[https://github.com/HKUDS/nanobot](https://github.com/HKUDS/nanobot)

Ultra-lightweight, open-source, self-hosted personal AI agent framework in Python with WebUI, tools, memory, MCP, multi-agent workflows, automation, and chat apps.

## First run

Set in `env.extra.json`:
- `AGENT_KAI_MISTRAL_API_KEY` → Obtained from [Mistral AI](https://mistral.ai/)
- `AGENT_KAI_OPENROUTER_API_KEY` → Obtained from [OpenRouter](https://openrouter.ai/)
- `AGENT_KAI_SANDBOX_TOKEN` → `openssl rand -hex 32`
- `AGENT_KAI_TELEGRAM_BOT_TOKEN` → Obtained from [BotFather](https://t.me/BotFather)
- `AGENT_KAI_WEB_TOKEN` → `openssl rand -hex 32`
- `AGENT_KAI_WS_TOKEN_ISSUE_SECRET` → `openssl rand -hex 32`

```sh
sudo bash -c 'source /srv/server/server.sh && server_build'                                 # Pre-build images
sudo bash -c 'source /srv/server/server.sh && server_compose run --rm nanobot-kai onboard'  # Guided config wizard
```

## Configuration

State (config, workspace, skills, sessions, memory) lives in `services/agents/kai/data/` → mounted at `/home/nanobot/.nanobot` in-container.

For Docker access to the WebUI, `config.json` must bind externally, the channel refuses to start on `0.0.0.0` without auth. Merge into `config.json`:

```json
{
  "gateway": {
    "host": "0.0.0.0"
  },
  "channels": {
    "websocket": {
      "enabled": true,
      "host": "0.0.0.0",
      "port": 8765,
      "token": "${NANOBOT_WEB_TOKEN}",
      "tokenIssueSecret": "${NANOBOT_WS_TOKEN_ISSUE_SECRET}"
    }
  }
}
```

Both secrets are defined in `env.extra.json`; Authelia protects the route in front of this, so the token is a second layer.

## Recommended/example config

Cost-first model lineup (Mistral small for daily work, big Mistral on demand, GLM/DeepSeek via OpenRouter for coding+lab, a free 550B for experiments), SearXNG search, Voxtral voice transcription.
Merge into `config.json` after `onboard`, alongside the gateway/websocket block above:

```json
{
  "providers": {
    "openrouter": { "apiKey": "${OPENROUTER_API_KEY}" },
    "mistral":    { "apiKey": "${MISTRAL_API_KEY}" },
    "openai":     { "apiKey": "${MISTRAL_API_KEY}", "apiBase": "https://api.mistral.ai/v1" }
  },
  "modelPresets": {
    "daily":       { "provider": "mistral",    "model": "mistral-small-latest", "maxTokens": 8192, "contextWindowTokens": 262144 },
    "daily-upper": { "provider": "mistral",    "model": "mistral-medium-latest", "maxTokens": 8192 },
    "coding":      { "provider": "openrouter", "model": "z-ai/glm-5.3-flash" },
    "lab":         { "provider": "openrouter", "model": "deepseek/deepseek-v4-flash" },
    "free":        { "provider": "openrouter", "model": "nvidia/nemotron-3-ultra-550b-a55b:free" }
  },
  "agents": {
    "defaults": {
      "modelPreset": "daily",
      "fallbackModels": ["coding"]
    }
  },
  "transcription": {
    "enabled": true,
    "provider": "openrouter",
    "model": "mistralai/voxtral-small-15b",
    "language": "es"
  },
  "tools": {
    "exec": { "enable": false },
    "web": {
      "search": {
        "provider": "searxng",
        "baseUrl": "${SEARXNG_BASE_URL}"
      }
    },
    "ssrfWhitelist": ["172.22.0.0/16", "172.23.0.0/16"],
    "mcpServers": {
      "sandbox": {
        "url": "http://nanobot-kai-sandbox:8000/mcp",
        "headers": { "Authorization": "Bearer ${SANDBOX_TOKEN}" }
      }
    },
    "imageGeneration": {
      "enabled": false,
      "provider": "openrouter",
      "model": "<image-model-id>"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_BOT_TOKEN}",
      "allowFrom": ["<your-telegram-user-id>"]
    }
  }
}
```

Notes:

* `${VAR}` placeholders resolve from the container environment (already wired in the compose file).
* `ssrfWhitelist` covers the compose networks so the agent can reach the internal SearXNG (`http://searxng:8080`) and the code sandbox (`http://nanobot-kai-sandbox:8000`). SearXNG's limiter bypasses the whole internal compose subnet (`pass_ip = 172.22.0.0/16`); bot detection stays active for public traffic arriving via Traefik.
* `tools.exec.enable: false` removes nanobot's own shell, all code execution goes through the sandbox sidecar (see below). Re-enable only if you accept an unsandboxed path.
* Register Mistral as BYOK under OpenRouter → Integrations so `mistralai/*` slugs draw from your Mistral quota; other models use OpenRouter credits.
* Transcription (Voxtral) runs through **OpenRouter** (`mistralai/voxtral-small-15b`), nanobot's transcription registry has no native `mistral` provider (upstream: [#1680](https://github.com/HKUDS/nanobot/pull/1680) closed unmerged, [#3513](https://github.com/HKUDS/nanobot/pull/3513) open). If OR rejects the model on its STT endpoint, fall back to `openai/whisper-1`. Billing goes through OpenRouter (BYOK for `mistralai/*` if configured).
* A complete reference `config.json` (full schema dump with every provider/channel/tool section) lives in [example.config.json](example.config.json), it is the source of truth for this README's snippets.
* Image generation stays disabled until you pick a backend, BFL Flux.2 Pro has no native provider here: check if OpenRouter lists an image-capable Flux model ID and drop it in, or front BFL's API with an OpenAI-Images-compatible gateway and use `provider: "custom"`.
* WhatsApp is preinstalled in the image: link with `server_compose run --rm nanobot-kai channels login whatsapp`, then add a `channels.whatsapp.allowFrom` block.

## Code execution sandbox

A dedicated sidecar container runs code on behalf of the agent with **no network access at all** (`agent-kai-internal` is a Docker `internal: true` network, no internet, no route to other services). nanobot reaches it as an MCP tool; the agent's own shell is disabled.

```
agent (brain: internet via server network, SSRF-guarded tools)
   │  MCP: run_code · read_file · list_packages · cleanup  (Bearer ${SANDBOX_TOKEN})
   ▼
nanobot-sandbox (hands: offline, 512MB / 1 CPU / 128 pids, read-only rootfs)
   └── /exchange  (shared bind mount: services/agents/kai/exchange/)
```

Exchange layout (`services/agents/kai/exchange/`, UID/GID 1000, git-ignored):

| Path | Written by | Purpose |
|---|---|---|
| `downloads/` | agent | files fetched from the internet (SSRF-guarded, logged) |
| `wheels/` | agent | `.whl` files for offline installs |
| `runs/<id>/` | sandbox | fresh dir per `run_code`: `script.*`, `outputs/` |

Usage patterns to teach the agent (it discovers them from the tool description, but prompt them too):

* **Fetch → compute**: "download X to /exchange/downloads, then run_code to process it", untrusted code never makes network requests; every inbound byte flows through nanobot's guarded fetch.
* **Missing library**: agent downloads the wheel into `/exchange/wheels/`, then the script does `pip install --no-index --find-links /exchange/wheels --target /tmp/libs <pkg>` and runs with `PYTHONPATH=/tmp/libs`. Common libs (pandas, openpyxl, Pillow, requests, matplotlib) are baked into the image.
* **Artifacts**: scripts write results to `outputs/`; nanobot reads them from the volume and sends them back over chat.

Operational notes:

* Sandbox source: `services/agents/sandbox/` (`server.py` + `requirements.txt` + Dockerfile, FastMCP streamable-HTTP at `/mcp`). Rebuild with `server_build nanobot-kai-sandbox`.
* `run_code` caps: 300 s max per run, 64 KB stdout/stderr returned (truncation flagged), run dirs auto-cleaned after 24 h / 100 runs.
* Hygiene tools: `list_packages` (what's installed offline) and `cleanup` (SIGKILLs every process except the server itself, timeout escapees included and optionally wipes `runs/`). `cleanup` is gated: it refuses to run unless the server is PID 1 of its own container, so it can never scan host processes. A disk guard refuses new runs while `/exchange` has less than 512 MB free; `cleanup(wipe_runs=true)` is the recovery path.
* Auth: `SANDBOX_TOKEN` (env.extra.json) is required on every MCP call; `/health` is the only unauthenticated endpoint.
* Deviation from AGENTS.md: the `agent-kai-internal` network is NOT added to adminer, the sandbox has no database and keeping adminer off that network preserves the isolation boundary.
* `bwrap` is intentionally not enabled: the sidecar supersedes it and avoids weakening the nanobot container's capabilities.

## File access and sync

Everything the agent writes persists on the host via the bind mount, nothing is trapped in the container:

* Code and files: `services/agents/kai/data/workspace/`
* Generated media: `services/agents/kai/data/media/generated/`
* Skills: `services/agents/kai/data/workspace/skills/`

Retrieval options:

1. **Chat-native** (preferred): ask the bot to show/send the artifact, the WebUI renders code and files with copy/download, Telegram/WhatsApp deliver documents and images as attachments.
2. **SSH/SCP**: pull directly from the paths above.
3. **Git**: for project workspaces, have the agent commit+push and pull locally.

Continuous sync to a local PC via this server's existing Syncthing:

* Share only a dedicated **outbox** folder (e.g. `data/workspace/outbox/`), ask the agent to drop finished work there.
* Never sync the whole `data/` directory: `sessions/` and memory files change on every message, causing constant churn and conflict risk.
* Agent files are owned by UID/GID 1000; make sure Syncthing can read them (see `server_set_storage_permissions` patterns).

## Updating

Images are built from source (nanobot pinned to a release tag, sandbox from this repo). Update NANOBOT_BUILD_REF to desired version in `env.json`, then:

```sh
source server.sh && gen_server_env && server_build nanobot-kai nanobot-kai-sandbox && server_up
```

The built image is tagged with the build ref (`nanobot-local:v0.3.0`).

## Notes

* Container runs as non-root UID/GID 1000.
* Default capabilities are dropped except `CHOWN`/`SETUID`/`SETGID`, with `no-new-privileges`. If enabling `"tools.exec.sandbox": "bwrap"`, extra privileges are required.
* Gateway health port `18790` stays internal (not published, not routed by Traefik).
* Parked features (recipes ready, not deployed):
  * [SIGNAL.md](SIGNAL.md), signal-cli sidecar, needs a real phone number
  * [TTS.md](TTS.md), voice replies via Voxtral TTS, needs the small voice sidecar.
