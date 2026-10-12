# agent-sandbox

Offline MCP code-execution sidecar.
- uv-managed (`pyproject.toml`, no lockfile)
- Python 3.14, nonroot
- `read_only` container
- No network access.

Tools:
- `run_code` (timeouts snap up to 60/300/900s)
- `run_template` (baked `templates/*.py`, `{{param}}` substitution)
- `save_artifact` (-> `/exchange/outputs/`)
- `read_file`
- `list_packages`
- `cleanup`

Bearer `SANDBOX_TOKEN` auth.

## Smoke test

```sh
# on the VPS (token already in the container env):
sudo docker exec <container> /app/.venv/bin/python /app/smoke_test.py
```

<container> -> nanobot-kai-sandbox

Locally: mount `tests/smoke_test.py` and `tests/example.pdf` (`exchange/tests/example.pdf`) into a container and run `/app/smoke_test.py [URL] [TOKEN]` — expect 14 passed, 0 failed.

## Updating the docker image

After changing `server.py`, `templates/`, or `pyproject.toml`:

```sh
source server.sh
server_build <container> 
server_compose up -d --force-recreate <container> 
```

<container> -> nanobot-kai-sandbox

Then re-run the smoke test. Template changes must be baked into the image — edit `templates/` and rebuild.
