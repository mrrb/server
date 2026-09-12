# Voice replies with Voxtral TTS (parked recipe)

Goal: kai answers voice notes **with audio attachments** on Telegram/WhatsApp/etc.,
using Mistral's **Voxtral TTS** (`voxtral-tts-2603`, v26.03 — zero-shot voice
cloning, multilingual).

Status: **parked** — needs a small sidecar (recipe below, ~1h of work).

## Architecture

nanobot has no TTS tool (only `generate_image`), and its own shell is disabled.
The pattern is the sandbox's mirror image: a small **online** MCP sidecar that
synthesizes audio and hands the file back as a media artifact.

```
agent (server network) ── MCP speak(text) ──► nanobot-kai-voice (bearer auth, egress OK)
                                                 └── POST /v1/audio/speech (api.mistral.ai)
                                                       └── writes ~/.nanobot/media/...wav
                                                             └── channels attach it to the reply
```

Generated media files under the nanobot media directory are attached to channel
replies exactly like generated images — no channel-specific code needed.

## 1. Endpoint + model

* `POST https://api.mistral.ai/v1/audio/speech` (nav: *Audio Speech*) — verify the
  request/response shape against the
  [API reference](https://docs.mistral.ai/api/#tag/audio) (OpenAI-speech-style).
* Model id: **`voxtral-tts-2603`** (verify with `GET /v1/models`).
* License: **CC BY-NC 4.0** — fine for a personal household, not for commercial use.
* Check pricing at [docs.mistral.ai/inference/pricing](https://docs.mistral.ai/inference/pricing)
  (likely per-character, like Transcribe 2's $0.003/min).

## 2. Service — `services/agents/kai/voice/` (server.py + requirements.txt + Dockerfile)

A minimal FastMCP server (copy the sandbox skeleton: bearer middleware, health
route, main()) with one tool:

```python
@mcp-style tool: speak(text: str, voice: str = "") -> dict
  1. POST /v1/audio/speech  { "model": "voxtral-tts-2603", "input": text, "voice": ... }
  2. save audio to EXCHANGE/voice/<run_id>.mp3 (or the nanobot media dir)
  3. return {"path": ..., "duration_estimate_s": ...}
```

* Runs **online**: join the `server` network (needs Mistral egress) — the bearer
  token is what keeps it private (`AGENT_KAI_TTS_TOKEN`, new env.extra.json key).
* Hardening like the sandbox: non-root, `no-new-privileges`, `cap_drop: ALL`,
  `mem_limit: 256m` (it only proxies HTTP + writes files), no pids issue.
* Watchtower disable label (locally built, unclaimed namespace) — same as sandbox.

## 3. Compose wiring

* New service `nanobot-kai-voice` (networks: `server`, volumes: exchange or media mount).
* `nanobot-kai` environment: `TTS_TOKEN: ${AGENT_KAI_TTS_TOKEN:-}`.
* `config.json` → `tools.mcpServers`:

```json
"voice": {
  "url": "http://nanobot-kai-voice:8000/mcp",
  "headers": { "Authorization": "Bearer ${TTS_TOKEN}" }
}
```

(`ssrfWhitelist` unchanged — the `server` subnet 172.22.0.0/16 is already there.)

## 4. Behavior prompt (workspace/skills/voice/SKILL.md)

> When the user asks for a voice answer (or sends a voice note), call
> `speak` with your reply text, then send the returned file as an attachment.
> Default voice: <cloned-voice-id>; keep replies short — audio is for tone,
> text is for content.

## Notes

* **License**: Voxtral TTS is CC BY-NC 4.0 — personal/household use is fine;
  no commercial products built on it.
* **Voice cloning**: zero-shot cloning needs a reference sample per voice —
  decide whose voice the "household" uses before enabling cloning.
* The agent should default to TEXT and only speak when asked (or per-channel
  preference) — voice notes for everything would get old fast and cost per char.
* Same recipe applies to future instances (jasper etc.) — one voice sidecar per
  instance, separate tokens.