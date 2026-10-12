# Kai - Nanobot AI agent

[https://github.com/HKUDS/nanobot](https://github.com/HKUDS/nanobot)

Ultra-lightweight, open-source, self-hosted personal AI agent framework in Python with WebUI, tools, memory, MCP, multi-agent workflows, automation, and chat apps.

## First run

Set in `env.extra.json`:
- `AGENT_KAI_MISTRAL_API_KEY` -> Obtained from [Mistral AI](https://mistral.ai/)
- `AGENT_KAI_OPENROUTER_API_KEY` -> Obtained from [OpenRouter](https://openrouter.ai/)
- `AGENT_KAI_TELEGRAM_BOT_TOKEN` -> Obtained from [BotFather](https://t.me/BotFather)
- `AGENT_KAI_SANDBOX_TOKEN` -> `openssl rand -hex 32`
- `AGENT_KAI_WS_TOKEN` -> `openssl rand -hex 32`
- `AGENT_KAI_WS_TOKEN_ISSUE_SECRET` -> `openssl rand -hex 32`

```sh
sudo bash -c 'source /srv/server/server.sh && server_build'                                 # Pre-build images
sudo bash -c 'source /srv/server/server.sh && server_compose run --rm nanobot-kai onboard'  # Guided config wizard
```

## Configuration

State (config, workspace, skills, sessions, memory) lives in `services/agents/kai/data/` -> mounted at `/home/nanobot/.nanobot` in-container.

After `onboard`, merge the blocks from [example.config.json](example.config.json) into `data/config.json`, it is the source of truth for the `${VAR}` placeholders (resolved from the container environment, wired in the compose file). Key points:

* `gateway.host: 0.0.0.0` + `channels.websocket` with `NANOBOT_WS_TOKEN` / `NANOBOT_WS_TOKEN_ISSUE_SECRET` are required for the WebUI to work behind Docker/Authelia. If the WebUI unlock says "Invalid" after a rename, recreate the container (`server_compose up -d --force-recreate nanobot-kai`); a plain restart keeps old env.
* `tools.exec.enable: false`, all code execution goes through the sandbox sidecar, never the agent's own shell.
* `ssrfWhitelist` covers the compose networks so the agent can reach internal SearXNG and the sandbox.

## Code execution sandbox

See `services/agents/sandbox/README.md` (tools, smoke test, image updates).

Dedicated sidecar (`services/agents/sandbox/`, uv-managed venv, deps in `pyproject.toml`/`uv.lock`) runs code with **no network access** (`agent-kai-internal` is `internal: true`); the agent reaches it as MCP tools (`run_code` — timeouts snap up to 60/300/900s — `run_template` for baked `templates/*.py`, `save_artifact`, `read_file`, `list_packages`, `cleanup`, Bearer `SANDBOX_TOKEN`). Files are exchanged via `services/agents/kai/exchange/` (UID/GID 1000, git-ignored); persistent artifacts belong in `exchange/outputs/` (run dirs are recycled). Rebuild with `server_build nanobot-kai-sandbox`.

## Updating

Update `NANOBOT_BUILD_REF` in `env.json`, then:

```sh
source server.sh && gen_server_env && server_build nanobot-kai nanobot-kai-sandbox && server_up
```

## Instance-only tweaks (reapply after data/ wipe or fresh onboard)

Runtime state in `data/` is not tracked by git — tweaks made there must be reapplied manually if the directory is reset:

* `data/workspace/SOUL.md`: append the section below so the agent never invents dates/times (nanobot (up to v0.3.5) never injects the current time into the prompt, so the model estimates otherwise; its `timezone` config param is parsed but unused):

```markdown
## Date and time
Never estimate or recall date/time. Always measure it first with run_code:
    import time; print(time.strftime("%Y-%m-%d %H:%M %Z"))
and report the measured value.
```

## Notes

* Container runs as non-root UID/GID 1000, capabilities dropped except `CHOWN`/`SETUID`/`SETGID`, `no-new-privileges`.
* Gateway health port `18790` stays internal (not published, not routed by Traefik).
