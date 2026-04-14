
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
FROM python:3.12-slim AS runtime
LABEL org.opencontainers.image.title="aks-assessment-app"
LABEL org.opencontainers.image.description="AKS Assessment – containerised Flask API"
LABEL org.opencontainers.image.authors="DevOps Team"
COPY --from=builder /install /usr/local
RUN groupadd --gid 10001 appgroup \
 && useradd  --uid 10001 --gid appgroup --shell /bin/false --no-create-home appuser
WORKDIR /app
COPY app.py .
RUN mkdir -p /mnt/secrets && chown appuser:appgroup /mnt/secrets
USER appuser
ENV PORT=8080 \
    APP_VERSION="1.0.0" \
    APP_ENV="production" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", \
     "--threads", "4", "--timeout", "60", \
     "--access-logfile", "-", "--error-logfile", "-", "app:app"]
