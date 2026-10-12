# Offline MCP code-execution sandbox

FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim

ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  UV_COMPILE_BYTECODE=1 \
  MPLCONFIGDIR=/tmp/mpl

COPY pyproject.toml /app/
WORKDIR /app
RUN uv sync --no-dev --no-install-project

RUN useradd --uid 1000 --create-home app

COPY server.py /app/server.py
COPY templates/ /app/templates/

USER 1000

EXPOSE 8000

CMD ["/app/.venv/bin/python", "/app/server.py"]
