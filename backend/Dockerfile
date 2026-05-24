FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Non-root user — create dirs first so volume mounts inherit ownership
RUN adduser --disabled-password --gecos '' appuser \
    && mkdir -p /app/db_data /app/.cache \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 5050

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5050", "--workers", "2", "--proxy-headers", "--forwarded-allow-ips", "172.0.0.0/8"]
