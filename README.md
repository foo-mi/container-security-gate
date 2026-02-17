# Container Pipeline — Build, Scan & Gate

A production-style container CI/CD pipeline that builds a hardened Docker image, runs automated vulnerability scanning with **Trivy**, gates the pipeline on critical CVEs, and only pushes a clean image to the registry.



---

## Pipeline Architecture

```
Push to main / PR
       │
       ▼
┌──────────────────────────────────────┐
│  Stage 1: Build                      │
│  Multi-stage Dockerfile              │
│  Docker Buildx + GHA layer cache     │
│  Saves image as tarball artifact     │
└──────────────┬───────────────────────┘
               │ needs: build
               ▼
┌──────────────────────────────────────┐
│  Stage 2: Trivy Vulnerability Scan   │
│  Scans ALL severities (CRIT→LOW)     │
│  Uploads SARIF → GitHub Security tab │
│  Does NOT fail pipeline (full view)  │
└──────────────┬───────────────────────┘
               │ needs: scan
               ▼
┌──────────────────────────────────────┐
│  Stage 3: Security Gate              │  ← Pipeline FAILS here if CRITICAL CVEs
│  Blocks on CRITICAL CVEs only        │    are found with available fixes
│  Writes pass/fail summary            │
└──────────────┬───────────────────────┘
               │ needs: security-gate
               │ only on: push to main
               ▼
┌──────────────────────────────────────┐
│  Stage 4: Push to Registry           │
│  Only runs after gate passes         │
│  PRs never push                      │
└──────────────────────────────────────┘
```

## Security Features in the Dockerfile

| Practice | Implementation |
|----------|---------------|
| Non-root user | `appuser` (UID 1001) created and enforced |
| Minimal base image | `python:3.12-slim` — fewer packages = smaller CVE surface |
| OS security updates | `apt-get upgrade` in base layer |
| Multi-stage build | `deps` stage never ships to production |
| No package manager cache | `apt-get clean && rm -rf /var/lib/apt/lists/*` |
| Zero third-party deps | stdlib only — no supply chain risk |
| Container health check | Kubernetes-compatible liveness probe |
| OCI labels | Image metadata for registry tracking |

## Scan Strategy

- **Daily scheduled scans** (06:00 UTC) catch newly published CVEs against existing images
- **`ignore-unfixed: true`** — only flags CVEs with available patches (actionable alerts only)
- **SARIF upload** — results visible in GitHub's Security tab with full CVE detail
- **Tiered response** — ALL severities tracked, only CRITICAL blocks the pipeline

## Running Locally

```bash
# Build the image
docker build -t devsecops-demo:local .

# Run the app
docker run -p 8080:8080 devsecops-demo:local

# Health check
curl http://localhost:8080/health

# Scan locally with Trivy (install: https://aquasecurity.github.io/trivy)
trivy image devsecops-demo:local
```

## Skills Demonstrated

| Skill | Where |
|-------|-------|
| Docker multi-stage builds | `Dockerfile` — base / deps / final stages |
| Container security hardening | Non-root, slim base, no cache, minimal deps |
| Trivy CVE scanning | `.github/workflows/container-scan.yml` Stage 2 |
| Pipeline security gating | Stage 3 — exit-code 1 on CRITICAL |
| SARIF / GitHub Security integration | `upload-sarif` action |
| Scheduled pipeline runs | `cron` trigger for daily re-scans |
| Artifact passing between jobs | `upload-artifact` / `download-artifact` |
| Registry push gating | Push only after security gate + only on main |
