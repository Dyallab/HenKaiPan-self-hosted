# Changelog

All notable changes to the self-hosted distribution are documented here.

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
