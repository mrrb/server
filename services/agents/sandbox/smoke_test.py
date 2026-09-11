#!/usr/bin/env python3

"""Smoke test for the nanobot-sandbox MCP server.

Verifies, against a RUNNING server:
  1. /health endpoint (no auth)
  2. bearer-auth enforcement (missing and wrong tokens are rejected)
  3. MCP protocol: tools/list returns the expected tools
  4. real execution: run_code computes, list_packages enumerates,
     cleanup returns a report

Usage:
  python smoke_test.py [URL] [TOKEN]

Defaults: URL=http://127.0.0.1:8000, token from $NANOBOT_SANDBOX_TOKEN.

Inside the sandbox container (token already in env):
  server_compose exec nanobot-sandbox python /app/smoke_test.py
"""

import asyncio
import json
import os
import sys
import urllib.error
import urllib.request


# Config
BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000").rstrip("/")
TOKEN = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("NANOBOT_SANDBOX_TOKEN", "")

EXPECTED_TOOLS = {"run_code", "read_file", "list_packages", "cleanup"}


# Globals
passed: list[str] = []
failed: list[str] = []


# Helpers
def check(name: str, ok: bool, detail: str = ""):
  """Report a test result."""

  (passed if ok else failed).append(name)
  mark = "PASS" if ok else "FAIL"
  suffix = f" — {detail}" if detail else ""

  print(f"[{mark}] {name}{suffix}")


def http(method: str, path: str, headers: dict[str, str] | None = None, data: bytes | None = None):
  """Make an HTTP request."""

  req = urllib.request.Request(BASE + path, method=method, headers=headers or {}, data=data)

  try:
    with urllib.request.urlopen(req, timeout=10) as resp:
      return resp.status, resp.read()
  except urllib.error.HTTPError as exc:
    return exc.code, exc.read()
  except OSError as exc:
    return None, str(exc).encode()


# Main
def main():
  print(f"Smoke test against {BASE}\n")

  # 1. health, no auth required
  status, body = http("GET", "/health")

  try:
    ok = status == 200 and json.loads(body).get("status") == "ok"
  except (json.JSONDecodeError, TypeError):
    ok = False

  check("Health endpoint reachable (no auth)", ok, f"status={status}")


  # 2. auth enforcement
  status, _ = http("POST", "/mcp", data=b"{}")
  check("missing token rejected", status == 401, f"status={status}")

  status, _ = http(
    "POST", "/mcp",
    headers={"Authorization": "Bearer definitely-wrong-token"},
    data=b"{}",
  )
  check("wrong token rejected", status == 401, f"status={status}")

  status, _ = http(
    "POST", "/mcp", headers={"Authorization": f"Bearer {TOKEN}"}, data=b"{}"
  )
  check("valid token accepted", status is not None and status != 401, f"status={status}")


  # 3+4. MCP protocol via a real client
  try:
    from fastmcp import Client
    from fastmcp.client.transports import StreamableHttpTransport
  except ImportError:
    check("MCP protocol checks", False, "fastmcp not installed on this machine")
  else:
    transport = StreamableHttpTransport(
      url=BASE + "/mcp",
      headers={"Authorization": f"Bearer {TOKEN}"},
    )

    async def protocol_checks():
      async with Client(transport) as client:
        tools = {t.name for t in await client.list_tools()}
        check("tools/list returns expected tools", tools == EXPECTED_TOOLS, f"got {sorted(tools)}")

        res = await client.call_tool(
          "run_code", {"language": "python", "code": "print(40 + 2)"},
        )
        data = res.data if hasattr(res, "data") else {}
        check(
          "run_code executes end-to-end",
          isinstance(data, dict) \
          and data.get("exit_code") == 0 \
          and data.get("stdout", "").strip() == "42",
          f"exit={data.get('exit_code') if isinstance(data, dict) else '?'} " + \
          f"stdout={data.get('stdout', '').strip() if isinstance(data, dict) else '?'}",
        )

        res = await client.call_tool("list_packages", {})
        data = res.data if hasattr(res, "data") else {}
        count = data.get("count") if isinstance(data, dict) else None
        check(
          "list_packages returns catalog", isinstance(count, int) and count > 0,
          f"{count} packages"
        )

        res = await client.call_tool("cleanup", {"wipe_runs": False})
        data = res.data if hasattr(res, "data") else {}

        ok = isinstance(data, dict) and (
          ("killed" in data and "disk_free_mb" in data) or "error" in data
        )
        detail = (
          data.get("error", "").split(".")[0]
          or f"disk_free_mb={data.get('disk_free_mb')}"
          if isinstance(data, dict)
          else "?"
        )
        check("cleanup responds (report or safe refusal)", ok, detail)

    try:
      asyncio.run(protocol_checks())
    except Exception as exc:
      check("MCP protocol checks", False, f"{type(exc).__name__}: {exc}")

  print(f"\nSMOKE TEST: {len(passed)} passed, {len(failed)} failed")
  return 0 if not failed else 1


if __name__ == "__main__":
  sys.exit(main())
