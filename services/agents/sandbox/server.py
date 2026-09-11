import os
import time
import uuid
import base64
import shutil
import signal
import uvicorn
import subprocess
import importlib.metadata

from typing import Any
from pathlib import Path
from fastmcp import FastMCP
from starlette.responses import JSONResponse


# Config
TOKEN = os.environ.get("NANOBOT_SANDBOX_TOKEN", "")

HOST = os.environ.get("NANOBOT_SANDBOX_HOST", "0.0.0.0")
PORT = int(os.environ.get("NANOBOT_SANDBOX_PORT", "8000"))

EXCHANGE_PATH = Path(os.environ.get("NANOBOT_SANDBOX_EXCHANGE", "/exchange"))
RUNS_PATH = EXCHANGE_PATH / "runs"

OUTPUT_CAP = 64 * 1024
READ_CAP = 256 * 1024
MAX_TIMEOUT = 300
MAX_RUNS = 100
RUN_TTL_S = 24 * 3600
MIN_FREE_BYTES = 512 * 1024 * 1024


# Helpers
def _disk_guard():
  try:
    usage = shutil.disk_usage(EXCHANGE_PATH)
  except OSError as exc:
    return False, f"cannot stat exchange volume: {exc}"

  if usage.free < MIN_FREE_BYTES:
    return False, (
      f"low disk on /exchange: {usage.free // (1024 * 1024)} MB free "
      f"(minimum {MIN_FREE_BYTES // (1024 * 1024)} MB). "
      "Recover with the cleanup tool (wipe_runs=true) or by clearing /exchange."
    )

  return True, ""


def _proc_stat_fields(pid: int | str):
  data = Path(f"/proc/{pid}/stat").read_text()
  after = data[data.rfind(")") + 2:].split()

  return int(after[2]), int(after[3])


def _proc_cmdline(pid: int | str):
  raw = Path(f"/proc/{pid}/cmdline").read_bytes()

  return " ".join(part.decode("utf-8", "replace") for part in raw.split(b"\0") if part)[:200]


def _is_containerized() -> bool:
  """True only when PID 1 is this server (own PID namespace = own container).

  - Inside the sandbox container the exec-form CMD makes the server PID 1.
  - On a host (dev/testing) PID 1 is an init system, and scanning+killing "all
  processes outside our session" would mean killing host processes.
  """
  try:
    pid1_cmd = Path("/proc/1/cmdline").read_bytes().decode("utf-8", "replace")
  except OSError:
    return False

  script_name = Path(__file__).name
  return script_name in pid1_cmd


def _cleanup_old_runs():
  try:
    run_dirs = sorted(RUNS_PATH.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
  except OSError:
    return

  now = time.time()
  for run_dir in run_dirs[MAX_RUNS:]:
    shutil.rmtree(run_dir, ignore_errors=True)

  for run_dir in run_dirs[:MAX_RUNS]:
    try:
      if now - run_dir.stat().st_mtime > RUN_TTL_S:
        shutil.rmtree(run_dir, ignore_errors=True)
    except OSError:
      pass


def _truncate(text: str | None, max_len: int = OUTPUT_CAP):
  """Truncate provided text to max_len (default: `OUTPUT_CAP`)

  Args:
    text: text to truncate

  Returns:
    tuple of (truncated text, whether text was truncated)
  """
  if text is None:
    return "", False

  if len(text) > OUTPUT_CAP:
    return text[:OUTPUT_CAP], True

  return text, False


def run_code(language: str, code: str, timeout_s: int = 60) -> dict[str, Any]:
  """Execute code inside the offline sandbox.

  - Runs in a fresh directory under /exchange/runs/<id>/ with 'outputs/' inside it for artifacts.
  - Input files must be placed in /exchange beforehand (e.g. /exchange/downloads).
  - No network access is available.
  - Supported languages: python, bash.
  """

  # Sanitize inputs
  lang = (language or "").strip().lower()

  if lang not in ("python", "bash"):
    return {"error": "language must be 'python' or 'bash'"}

  if not isinstance(code, str) or not code.strip():
    return {"error": "code must be a non-empty string"}

  # Check disk space
  ok, reason = _disk_guard()
  if not ok:
    return {"error": reason}

  # Prepare run
  timeout = min(max(int(timeout_s or 60), 1), MAX_TIMEOUT)
  _cleanup_old_runs()

  run_id = uuid.uuid4().hex[:12]
  run_dir = RUNS_PATH / run_id
  outputs_dir = run_dir / "outputs"
  outputs_dir.mkdir(parents=True, exist_ok=True)

  script_name = "script.py" if lang == "python" else "script.sh"
  script_path = run_dir / script_name
  script_path.write_text(code)
  script_path.chmod(0o700)

  cmd = ("python3", script_name) if lang == "python" else ("bash", script_name)

  started = time.monotonic()
  timed_out = False

  # Run the code
  try:
    proc = subprocess.Popen(
      cmd,
      cwd=run_dir,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      text=True,
      start_new_session=True,
    )

    try:
      stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
      timed_out = True

      try:
        os.killpg(proc.pid, signal.SIGKILL)
      except OSError:
        proc.kill()

      stdout, stderr = proc.communicate()
  except OSError as exc:
    return {"error": f"failed to start process: {exc}", "run_id": run_id, "run_dir": str(run_dir)}

  # Process results and return
  duration = round(time.monotonic() - started, 3)
  stdout, stdout_trunc = _truncate(stdout)
  stderr, stderr_trunc = _truncate(stderr)

  return {
    "run_id": run_id,
    "exit_code": proc.returncode,
    "timed_out": timed_out,
    "duration_s": duration,
    "stdout": stdout,
    "stderr": stderr,
    "stdout_truncated": stdout_trunc,
    "stderr_truncated": stderr_trunc,
    "run_dir": str(run_dir),
    "outputs_dir": str(outputs_dir),
  }


def list_packages() -> dict[str, Any]:
  """List Python packages installed in the sandbox image (name==version, sorted).

  - Check this before writing code so scripts only use libraries that are available offline.
  - Anything missing must be provided as a wheel in /exchange/wheels
    (installed at runtime with pip --no-index).
  """

  try:
    packages = []
    for dist in importlib.metadata.distributions():
      name = dist.metadata.get("Name")
      if name:
        packages.append(f"{name}=={dist.version}")
  except Exception as exc:
    return {"error": f"failed to enumerate packages: {exc}"}

  packages.sort(key=str.lower)

  return {"count": len(packages), "packages": packages}


def cleanup(wipe_runs: bool = False) -> dict[str, Any]:
  """Kill every process in the sandbox except this server, optionally wiping run dirs.

  - Use when a job is stuck or orphaned processes are suspected
    (e.g. scripts that escaped a timeout via setsid).
  - The main server and its own process group are never touched.
  - With wipe_runs=true, ALL directories under /exchange/runs are deleted,
    including outputs you may still need, so read them first.
  - Returns the disk state afterwards for verification.
  """

  # Safety check: only run inside own container (own PID namespace).
  # On a host, refuse instead.
  if not _is_containerized():
    return {
      "error": (
        "cleanup refused: this server is not running inside its own container "
        "(PID 1 is not the sandbox). Killing host processes is not allowed."
      ),
      "killed": [],
      "runs_wiped": None,
    }

  # Get own process group and session IDs
  my_pid = os.getpid()
  my_pgid = os.getpgid(0)
  my_sid = os.getsid(0)

  # List all processes in /proc, excluding ourself and our process group
  candidates = []
  for proc_dir in Path("/proc").iterdir():
    # Skip non-process directories
    if not proc_dir.name.isdigit():
      continue

    # Get PID and skip if it's our own
    pid = int(proc_dir.name)
    if pid == my_pid:
      continue

    # Get process group and session IDs and skip if they match ours
    try:
      pgid, sid = _proc_stat_fields(pid)
    except (OSError, ValueError, IndexError):
      continue

    if pgid == my_pgid or sid == my_sid:
      continue

    # Candidate found!
    candidates.append(pid)

  # Time to kill them all
  killed, errors = [], []
  for pid in candidates:
    try:
      cmdline = _proc_cmdline(pid)
    except OSError:
      cmdline = ""

    try:
      os.kill(pid, signal.SIGKILL)
      killed.append({"pid": pid, "cmdline": cmdline})
    except ProcessLookupError:
      pass
    except OSError as exc:
      errors.append({"pid": pid, "error": str(exc)})

  # Wipe runs if requested
  runs_wiped = None
  if wipe_runs:
    runs_wiped = 0
    if RUNS_PATH.exists():
      for run_dir in RUNS_PATH.iterdir():
        shutil.rmtree(run_dir, ignore_errors=True)
        runs_wiped += 1

  # Get disk free space
  free_mb = None
  try:
    free_mb = shutil.disk_usage(EXCHANGE_PATH).free // (1024 * 1024)
  except OSError:
    pass

  # Return
  return {
    "killed": killed,
    "errors": errors,
    "runs_wiped": runs_wiped,
    "disk_free_mb": free_mb,
  }


def read_file(path: str) -> dict[str, Any]:
  """Read a text file from /exchange (small files only, binary not supported).

  - Use for quick inspection of run outputs; larger or binary artifacts should
    be read directly from the exchange volume by the caller.
  """

  # Validate path
  try:
    target = Path(path).resolve()
    target.relative_to(EXCHANGE_PATH.resolve())
  except (ValueError, OSError):
    return {"error": "path must be inside /exchange"}

  # Ignore directories
  if not target.is_file():
    return {"error": f"not a file: {path}"}

  # Skip large files
  size = target.stat().st_size
  if size > READ_CAP:
    return {"error": f"file too large ({size} bytes, cap {READ_CAP})", "size": size}

  # Read file
  try:
    content = target.read_text(encoding="utf-8")
  except UnicodeDecodeError:
    try:
      content_b64 = base64.b64encode(target.read_bytes()).decode("ascii")
    except OSError as exc:
      return {"error": f"read failed: {exc}"}

    return {"path": str(target), "size": size, "encoding": "base64", "content": content_b64}

  return {"path": str(target), "size": size, "encoding": "utf-8", "content": content}


async def health(request):
  return JSONResponse({"status": "ok"})


class BearerAuthMiddleware:
  def __init__(self, app: FastMCP, token: str):
    self.app = app
    self.token = token

  async def __call__(self, scope, receive, send):
    if scope["type"] == "http" and self.token:
      path = scope.get("path", "")
      if path != "/health":
        headers = {
          k.decode("latin-1").lower(): v.decode("latin-1")
          for k, v in scope.get("headers", [])
        }
        if headers.get("authorization") != f"Bearer {self.token}":
          response = JSONResponse({"error": "unauthorized"}, status_code=401)
          await response(scope, receive, send)
          return

    await self.app(scope, receive, send)


def main():
  # Init
  RUNS_PATH.mkdir(parents=True, exist_ok=True)

  # MCP instance
  mcp = FastMCP("nanobot-sandbox")

  # Register tools
  mcp.tool(run_code)
  mcp.tool(list_packages)
  mcp.tool(cleanup)
  mcp.tool(read_file)
  mcp.custom_route("/health", methods=["GET"])(health)

  app = mcp.http_app(path="/mcp")

  # Run it!
  uvicorn.run(BearerAuthMiddleware(app, TOKEN), host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
  main()
