# Changelog

All notable changes to the self-hosted distribution are documented here.

## 1.8.2 — 2026-05-16

### Fixes

- **PR merge ref clone failure**: `git clone --branch refs/pull/N/merge` failed because PR refs are internal GitHub refs that don't exist in the remote. Now clones normally, then fetches the specific ref via `git fetch`
- **Action PR comments not posting**: `PR_NUMBER` was never passed to the Docker container. Now extracted from `$GITHUB_EVENT_PATH` at runtime. `GITHUB_TOKEN` also properly passed via `env:` block

## 1.8.1 — 2026-05-15

### Fixes

- **Migration idempotency**: Added `IF NOT EXISTS` to `CREATE TABLE` and `CREATE INDEX` in migration 035 so it can be re-run safely
- **Advisory lock for migrations**: Acquires a `pg_advisory_lock` during `RunMigrations` to prevent concurrent runs from api and worker containers colliding
- **Empty tokens array**: `GET /api/v1/tokens` now returns `[]` instead of `null` when no tokens exist, for consistent frontend handling

### Improvements

- **Branch syntax in clone URL**: Support `url#branch` syntax in project repo URLs (e.g. `https://github.com/user/repo#main`) — the specified branch is passed to `git clone --branch`
- **Copy project ID**: Each project card now shows its UUID with a copy-to-clipboard button for quick reference
- **Cleaner scanner UI**: Removed redundant "Via Docker" label in scanner settings

## 1.8.0 — 2026-05-14

### Features

- **CI/CD Integration API**: New `POST /api/v1/scans/external` endpoint allows external CI/CD systems (GitHub Actions, GitLab CI, Jenkins, CircleCI) to trigger security scans via API key authentication
- **API Token Management**: Full CRUD for API tokens at `/api/v1/tokens` (JWT auth). Tokens use `hkp_<64 hex>` format, bcrypt-hashed, shown only once at creation, with optional per-project scope
- **GitHub Action (`dyallab/henkaipan-action`)**: Docker-based action with `fail-on-severity`, automatic PR comments, and full findings summary. Available at GitHub Marketplace
- **Token UI in Settings**: New "API Tokens" section in Settings → Tokens with create modal (name + project scope) and token shown once on creation, revoke with confirmation

### Improvements

- **Shared scan creation helpers**: `resolveScanners()` and `createScanRecords()` unified between internal and external scan creation paths
- **API versioning**: External CI/CD endpoints live at `/api/v1/scans/external` and `/api/v1/scans/{id}/status` with separate API key auth (no JWT passthrough)
- **Documentation**: New setup guides for GitHub Actions, GitLab CI, Jenkins, CircleCI, and workflow examples for Node.js, Go, Python, and Docker stacks

## 1.7.0 — 2026-05-12

### Features

- **`--skip-ollama` flag**: New installer flag to skip Ollama installation, model pulling, and .env configuration. Useful when Ollama is already running elsewhere or AI summaries aren't needed
- **Auto-start stack**: Installer now runs `docker compose up -d` automatically after pulling images — no manual step needed
- **IP detection in summary**: Installer displays the machine's IP address instead of `localhost` in the done message, so users can open the UI from another PC

### Improvements

- **Simplified docker-compose**: Removed all `cap_drop` / `cap_add` hardening for a cleaner development experience
- **Streamlined installer**: Removed admin password prompt — defaults to `admin / admin` on first login (as documented)
- **Robust image pulling**: Replaced broken background-subshell pull loop with synchronous `docker compose pull`
- **Better error resilience**: Added `|| true` to grep pipelines to prevent `pipefail` from crashing the script on missing variables

### Fixes

- **Missing `REDIS_ADDR`**: Added `REDIS_ADDR=redis:6379` to `.env.example` and installer — API would crash on startup without it
- **Missing `POSTGRES_*` variables**: Added `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` to `.env.example` and installer — required by the postgres container
- **Missing `ADMIN_PASS`**: Added `ADMIN_PASS=admin` to `.env.example` so the installer's sed replacement works correctly
- **Ollama vars always active**: Commented out `OLLAMA_URL` and `OLLAMA_MODEL` in `.env.example` so `--skip-ollama` actually disables them


## 1.6.0 — 2026-05-09

### Features

- **Per-app scan scheduling**: Schedules can now target entire apps (`app_id` column on `scan_schedules`). When an app is selected, the schedule triggers scans for all projects belonging to that app — mutually exclusive with per-project schedules
- **GitHub repository discovery**: New pattern-based repo resolution engine (`internal/github/` package) supporting glob patterns (`org/*`, `@user/*`, `org/repo-*`) via GitHub API search — simplifies project onboarding at scale
- **Bulk project import**: `POST /api/projects/bulk` endpoint to import multiple projects at once from a GitHub pattern match, with `BulkCreateProjects` repository operation
- **Bulk project assignment**: `POST /api/projects/bulk-assign` endpoint to batch-reassign projects to an app, with `AssignProjectsToApp` repository operation
- **Vulnerability Inventory**: New free-tier routes `/api/vulnerabilities` and `/api/vulnerabilities/{vulnID}/affected` for aggregating and tracking vulnerability entries across the organization
- **Pattern-based project filtering**: `GET /api/projects` now supports `?pattern=` query param for glob-based project lookup via `ListStandaloneByPattern`

### Improvements

- **Scanner packs**: `ResolvePack` groups related scanners for bulk execution — a single scanner selector can now trigger multiple scanners
- **Per-app scan triggering**: Create scans targeting entire apps from the UI and API (`app_id` field in scan creation payload)
- **Enhanced projects dashboard**: Major UI rework with app context, pattern-based filtering, and project management actions
- **Enhanced scans dashboard**: Major UI rework with per-app filtering and scan triggering
- **Enhanced schedules dashboard**: Major UI rework with app-level schedule management, app selector, and schedule status visibility
- **Validation struct tags**: Added proper `json:` tags to `CreateProjectRequest` and extended model with `Provider` and `DefaultBranch` fields
- **Defensive nil-safety**: Apps list now returns empty slice instead of nil for `Projects` field

### Fixes

- **Rate limiting refinements**: Adjusted rate limiting middleware for better reliability under concurrent requests
- **Frontend API client cleanup**: Removed unused code paths from `api.ts`

## 1.5.1 — 2026-05-09

### Fixes

- **API Docker build**: Fixed `pnpm install` failure in API Docker image — pnpm 11 blocks esbuild/sharp build scripts by default, now uses `--ignore-scripts` + explicit `pnpm rebuild`

## 1.5.0 — 2026-05-09

### Improvements

- **Scanner execution model**: Scanners now run as embedded binaries in the worker process instead of Docker containers — eliminates Docker socket requirement entirely
- **Reduced attack surface**: Worker no longer mounts `/var/run/docker.sock` — no root-equivalent access needed
- **Simplified deployment**: No per-scanner container orchestration, no image pulls, no volume mounts
- **Kubernetes manifests**: Removed `docker.sock` hostPath volume from worker deployment
- **Docker Compose hardening**: Worker now runs as non-root user (uid 1000) with read-only root filesystem, matching Kubernetes security context

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
