# Changelog

All notable changes to the self-hosted distribution are documented here.

## 1.5.0 — 2026-05-09

### Improvements

- **Scanner execution model**: Scanners now run as embedded binaries in the worker process instead of Docker containers — eliminates Docker socket requirement entirely
- **Reduced attack surface**: Worker no longer mounts `/var/run/docker.sock` — no root-equivalent access needed
- **Simplified deployment**: No per-scanner container orchestration, no image pulls, no volume mounts
- **Kubernetes manifests**: Removed `docker.sock` hostPath volume from worker deployment

### Fixes

- **Semgrep scan failure**: Fixed exit code 2 caused by incorrect target path argument (`semgrep` was passed as scan target instead of repo directory)

### Removed

- **Docker-based scanner execution**: `docker/scanners/*.Dockerfile` deleted (semgrep, gosec, checkov standalone images)
- **Makefile targets**: `build-scanner-slim` and `build-all` removed — scanner binaries bundled in worker image
- **Dead code**: `Scanner.Image`, `Scanner.MountDst`, `Scanner.Entrypoint`, `Scanner.ExtraVolumes` fields removed from registry

## 1.4.1 — 2026-05-09

### Fixes

- **Worker seccomp profile**: Added `clone`, `clone3`, `arch_prctl`, `mbind` syscalls required by Go 1.26 runtime (prevented worker startup with segmentation fault)
- **Scanner compatibility**: Checkov prebuilt binaries incompatible with Alpine musl libc — reverted to pip installation
- **Semgrep pysemgrep wrapper**: Added wrapper script for Python module execution
- **GitHub release URLs**: Fixed asset download URLs for gitleaks, trufflehog, kics, nuclei, gosec (version-specific instead of `latest/download` which returns 404)

## 1.4.0 — 2026-05-08

### Security

- **Defense-in-depth hardening**: All services now follow least-privilege principle
- **cap_drop ALL**: Baseline capability restriction on every service
- **Minimal cap_add**: Only required capabilities added per service:
  - postgres: CHOWN, SETUID, SETGID, DAC_OVERRIDE
  - redis: CHOWN, SETUID, SETGID
  - worker: FOWNER, FSETID, DAC_OVERRIDE, CHOWN, SETUID, SETGID
  - api: no additional capabilities
- **no-new-privileges**: Applied to all services
- **Docker socket removed**: Worker no longer mounts `/var/run/docker.sock`
- **Scanner binary execution**: Scanners run as binaries via `os/exec` (no Docker)
- **Security headers**: CSP, X-Frame-Options, X-XSS-Protection, HSTS on all API responses
- **Input validation**: Backend (go-playground/validator) + Frontend (Zod) on all endpoints
- **IDOR prevention**: Ownership middleware on all resource endpoints with admin bypass
- **JWT hardening**: No default secret, expiration required, SetSecret() enforcement
- **Error sanitization**: Production mode hides internal error details
- **Rate limiting fail-closed**: Requests blocked when Redis is unavailable

## 1.3.0 — 2026-05-07

### Features

- **Real-time SSE updates**: Server-Sent Events system delivers AI summary, validation, scan, webhook, and notification events to the browser without polling
- **Redis pub/sub bridge**: Cross-process event delivery from worker to API via Redis channel `aspm:events`, enabling real-time updates in Docker Compose and multi-process deployments
- **SSE client library**: Frontend SSEClient singleton with automatic reconnection, event type filtering, and connection status monitoring

### Improvements

- **AI summary deduplication**: `PrepareAISummary()` sets `summary_state = pending` immediately in DB, preventing duplicate requests (returns 202 for pending, 200 for ready)
- **Asynq Unique(5min)**: Summary and validation tasks now use deduplication to prevent duplicate queue entries
- **SSE event architecture**: All known event types registered as EventSource listeners — pages subscribe via `.on()` handlers without specifying types upfront

### Fixes

- **SSE events never reached browser**: SSEClient singleton only registered filtered event types in `addEventListener`. Pages subscribing later got stale instance with wrong filters. Fix: ALL_SSE_EVENT_TYPES constant, always register all known types
- **AI summary auto-request on page load**: Removed `maybeQueueFindingSummary` from `GetFinding` handler and disabled `enqueueFindingSummary` in scan_run (commented out for future re-enablement)
- **Blue information toast on finding detail**: Removed invasive toast notification that appeared when viewing findings without descriptions
- **SSE disconnect on page navigation**: Removed `beforeunload` handler that killed the shared singleton connection

### Configuration

- **Redis pub/sub**: Worker publishes events to Redis channel `aspm:events`; API subscribes and relays to browser clients. No additional configuration needed — uses existing `REDIS_ADDR`

## 1.2.0 — 2026-05-05

### Operations & Production Documentation

- **Production Deployment Guide** (`docs/production-deployment.md`): Reverse proxy setup (nginx + certbot, Caddy), TLS/HTTPS, security hardening (Docker socket mitigation, firewall rules, secrets management), upgrade with rollback procedures, monitoring (Prometheus, health checks), resource sizing guide, production checklist
- **Operations Guide** (`docs/operations.md`): Worker scaling (multi-worker, queue monitoring), scanner runtime requirements (13 scanners with RAM/CPU/network specs), comprehensive troubleshooting guide (13 common issues with diagnosis and fixes), routine maintenance (log rotation, DB maintenance, SSL renewal, Docker cleanup)

### Improvements from Sentry Self-Hosted

Adopted best practices from https://github.com/getsentry/self-hosted (9.3k stars):

- **YAML anchors in docker-compose.yml**: DRY configuration with shared healthcheck defaults, restart policies, and environment file references
- **Enhanced install.sh**: Cleanup on exit, better error handling, architecture detection, fail-fast on minimum requirements
- **Optimized healthchecks**: 30s intervals (vs 5s) to reduce CPU usage - references moby/moby#39102, getsentry/self-hosted#1000
- **PostgreSQL optimizations**: shared_buffers=256MB, max_connections=1000, shm_size=256m
- **Redis optimizations**: AOF persistence, maxmemory=512mb, LRU eviction policy
- **Pull policy**: `pull_policy: always` for predictable updates

### Documentation

- **Kubernetes manifests**: Production-ready K8s deployment files (Deployments, Services, ConfigMaps, Secrets, Ingress)
- **Kubernetes deployment guide**: Comprehensive documentation for K8s deployment, scaling, monitoring, and troubleshooting
- **AI feature clarification**: Documented that self-hosted free tier only supports AI Summary (via Ollama); AI Remediation and Validation require license key
- **Admin password clarification**: Documented that `ADMIN_PASS` is optional and defaults to `admin`

### Configuration

- **Kubernetes support**: Added `kubernetes/` directory with manifests for production deployment
- **Monitoring configuration**: Added `monitoring/prometheus.yml` example configuration
- **Environment variable updates**:
  - `ADMIN_PASS` is now optional (previously listed as required)
  - Default admin credentials: `admin`/`admin` (hardcoded in migration)

### Files Added

- `kubernetes/namespace.yaml` — Namespace definition
- `kubernetes/configmap.yaml` — Non-sensitive configuration
- `kubernetes/secrets.yaml` — Sensitive credentials template
- `kubernetes/postgres.yaml` — PostgreSQL deployment + PVC + Service
- `kubernetes/redis.yaml` — Redis deployment + Service
- `kubernetes/api.yaml` — API deployment + Service
- `kubernetes/worker.yaml` — Worker deployment (Docker socket required)
- `kubernetes/ingress.yaml` — Ingress with TLS support
- `kubernetes/all-in-one.yaml` — Single manifest for testing
- `kubernetes/README.md` — Kubernetes file reference
- `monitoring/prometheus.yml` — Prometheus scrape configuration
- `docs/kubernetes-deployment.md` — Comprehensive K8s deployment guide

---

## 1.1.0 — 2026-05-03

### Security

- **Rate limiting middleware**: Redis-based rate limiter with per-endpoint tiers (auth: 10/min, heavy: 20/min, general: 100/min), X-RateLimit-* headers, and fail-open behavior on Redis errors
- **Webhook payload signing**: HMAC-SHA256 signing with constant-time comparison and 5-minute timestamp window for all webhook notifications
- **CORS configuration**: New `CORS_ALLOWED_ORIGINS` environment variable for multi-origin setups

### Features

- **Ollama AI provider**: Free, self-hosted AI option for remediation, summary, and validation tasks. Configure via `OLLAMA_URL` and `OLLAMA_MODEL` environment variables
- **Prometheus metrics**: Metrics endpoint exposed on port 9090 with queue/DB collectors for monitoring
- **Standardized error responses**: Centralized error handling with machine-readable error codes and metadata support

### Fixes

- **Frontend embedding**: Added `embed.go` and `noembed.go` with build tags for proper frontend embedding in production builds
- **Gitignore patterns**: Fixed `api` and `worker` patterns to only match root-level binaries, preventing `cmd/api/` from being ignored

### Configuration Changes

- **New environment variables**:
  - `CORS_ALLOWED_ORIGINS` — Comma-separated list of allowed origins
  - `OLLAMA_URL` — Ollama API URL (default: `http://localhost:11434`)
  - `OLLAMA_MODEL` — Ollama model (default: `gemma4:e4b`)
  - `AI_REMEDIATION_PROVIDER` — AI provider for remediation (`ollama`, `openrouter`, `cloudflare`)
  - `AI_SUMMARY_PROVIDER` — AI provider for summaries
  - `AI_VALIDATION_PROVIDER` — AI provider for validation
  - `PROMETHEUS_PORT` — Metrics endpoint port (default: `9090`)

---

## 1.0.0 — 2026-05-02

Initial release of the self-hosted edition.

### Features

- **Single-container deployment**: API with embedded frontend on port 8080
- **Unlimited free tier**: projects, users, all scanners, webhooks — no license key required
- **13 security scanners**: SAST (semgrep, gosec), SCA (trivy, grype, osv-scanner), Secrets (trufflehog, gitleaks), IaC (checkov, tfsec, kics), Containers (trivy-image, grype-image), DAST (nuclei)
- **Findings management**: triage workflow, SLA tracking, severity filters, CSV export
- **Scheduled scans**: cron-based periodic scanning
- **Policies & auto-triage**: rule-based finding suppression and status assignment
- **Compliance frameworks**: SOC 2 Type II, ISO 27001, PCI-DSS control mapping
- **Integrations**: Jira, GitHub PR comments, Slack webhooks, email notifications
- **AI remediation**: automated fix suggestions via OpenRouter or Cloudflare Workers AI
- **Team management**: role-based access (admin, analyst, viewer)
- **Audit log**: full compliance trail of security-relevant changes
- **Risk acceptance workflow**: formal risk acceptance process

### Packaging

- Docker images published to `ghcr.io/henkaipan/`
- Optional slim scanner images via `make build-scanner-slim`
- Backup/restore documentation
- Self-hosted licensing documentation

### System Requirements

- Docker & Docker Compose v2.24+
- 8 GB RAM minimum (16 GB recommended)
- 30 GB free disk
