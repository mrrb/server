FROM python:3.14-slim

ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

RUN useradd --uid 1000 --create-home app

COPY server.py /app/server.py
COPY smoke_test.py /app/smoke_test.py

USER 1000

EXPOSE 8000

CMD ["python", "/app/server.py"]
