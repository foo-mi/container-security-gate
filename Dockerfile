# ─────────────────────────────────────────────────────────────────────────────
# Hardened Python Container

# ─────────────────────────────────────────────────────────────────────────────

# Stage 1: Base — pin exact digest for supply-chain security
# Using slim variant to minimize attack surface (fewer packages = fewer CVEs)
FROM python:3.12-slim AS base

# ── Security hardening ────────────────────────────────────────────────────────

# Run as non-root user — critical security control
# Never run containers as root in production
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/sh --create-home appuser

# Install security updates in base layer
# apt-get clean and rm -rf reduce final image size and remove package manager cache
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Stage 2: Dependencies ─────────────────────────────────────────────────────
FROM base AS deps

WORKDIR /build

# Copy only requirements first — leverages Docker layer cache
# If requirements.txt doesn't change, pip install layer is reused
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ── Stage 3: Final image ─────────────────────────────────────────────────────
FROM base AS final

# Label metadata — good practice for image tracking in registries
LABEL org.opencontainers.image.title="contq" \
      org.opencontainers.image.description="DevSecOps pipeline demonstration app" \
      org.opencontainers.image.source="https://github.com/foo-mi/devsecops-pipeline-demo"

WORKDIR /app

# Copy installed packages from deps stage (multi-stage keeps final image clean)
COPY --from=deps /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages

# Copy application code
COPY app/ .

# Set ownership to non-root user
RUN chown -R appuser:appgroup /app

# Drop to non-root user
USER appuser

# Expose port (document intent — actual binding controlled at runtime)
EXPOSE 8080

# Health check for container orchestrators (Kubernetes liveness probe equivalent)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Explicit entrypoint — never use CMD alone, makes intent unambiguous
ENTRYPOINT ["python", "server.py"]
