# HenKaiPan ASPM — Self-Hosted

Application Security Posture Management platform. Self-hosted edition.

📚 **Documentation**: [Quickstart](https://henkaipan.dyallab.com.ar/docs/quickstart/) | [Licensing](https://henkaipan.dyallab.com.ar/docs/licensing/) | [Backup & Restore](https://henkaipan.dyallab.com.ar/docs/backup/)

## Prerequisites

- **Docker** & **Docker Compose** (v2.24+)
- **8 GB RAM** minimum (16 GB recommended for concurrent scans)
- **30 GB free disk** — scanner images are ~6 GB, plus app images and data

## Quickstart

### Docker Compose (Recommended for local/dev)

```bash
# 1. Run the installer (checks prerequisites, generates secrets)
./install.sh                 # with Ollama (free AI summaries)
./install.sh --skip-ollama   # without Ollama

# 2. Start
docker compose up -d

# 3. Open http://localhost:8080
#    Login with admin / admin (change after first login!)
```

### Kubernetes (Production)

See [Kubernetes Deployment Guide](docs/kubernetes-deployment.md) for production K8s deployment.

```bash
# Quick test deployment
kubectl apply -f kubernetes/all-in-one.yaml
kubectl port-forward svc/henkaipan-api 8080:8080 -n henkaipan
```

### Installer flags

| Flag | Description |
|------|-------------|
| `--skip-ollama` | Skip Ollama installation, model pull, and .env configuration. Use this if you don't need AI summaries or prefer to configure Ollama manually later. |

### Manual setup (without install.sh)

```bash
cp .env.example .env
# Edit .env: set JWT_SECRET, SECRET_ENCRYPTION_KEY
# ADMIN_PASS is optional - defaults to "admin" if not set
docker compose up -d
```

## Configuration

See `.env.example` for all options. Required variables:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Auth token signing key |
| `SECRET_ENCRYPTION_KEY` | Encryption key for stored secrets |

Optional variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ADMIN_PASS` | Admin password (set on first run only) | `admin` |
| `COOKIE_SECURE` | Set `true` behind HTTPS | `false` |
| `COOKIE_DOMAIN` | Cookie domain (e.g. `.example.com`) | empty |
| `COOKIE_SAMESITE` | SameSite policy: `lax`, `strict`, or `none` | `lax` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowed origins | localhost origins |
| `PROMETHEUS_PORT` | Prometheus metrics endpoint | `9090` |

### Kubernetes Configuration

For Kubernetes deployments, environment variables are configured via `ConfigMap` and `Secret` resources. See [Kubernetes Deployment Guide](docs/kubernetes-deployment.md) for details.

### AI Providers

The self-hosted edition supports multiple AI providers with different capabilities:

**Free tier (no license key):**
- **Ollama** (FREE, self-hosted) — Summary ONLY. Set `OLLAMA_URL` and `OLLAMA_MODEL`
- Summary generation for findings is available without a license key

**Paid features (require license key with `ai-remediation` feature):**
- **Remediation** — Automated fix suggestions via OpenRouter, Cloudflare, or Ollama
- **Validation** — AI-powered false positive detection

Configure providers per task using `AI_REMEDIATION_PROVIDER`, `AI_SUMMARY_PROVIDER`, and `AI_VALIDATION_PROVIDER`.

For a license key, contact **sales@dyallab.com.ar**.

### Monitoring

Prometheus metrics are exposed on port `9090` (configurable via `PROMETHEUS_PORT`). Includes queue and database metrics collectors.

**Access metrics:**

```bash
# Docker Compose
curl http://localhost:9090/metrics

# Kubernetes
kubectl port-forward svc/henkaipan-api 9090:9090 -n henkaipan
curl http://localhost:9090/metrics
```

**Sample Prometheus configuration:**

```yaml
scrape_configs:
  - job_name: 'henkaipan-api'
    static_configs:
      - targets: ['api:9090']
    metrics_path: /metrics
    scrape_interval: 10s
```

See `monitoring/prometheus.yml` for a complete example configuration.

### Rate Limiting

Redis-based rate limiting is enabled by default with per-endpoint tiers:
- Auth endpoints: 10 requests/min
- Heavy operations: 20 requests/min
- General endpoints: 100 requests/min

Rate limit headers (`X-RateLimit-*`) are included in responses. The system fails open on Redis errors.

## License Key

The app runs in **free mode** without a license key — no time limit. Features available:

- Unlimited projects & users
- All scanners (SAST, SCA, Secrets, IaC, Containers)
- Findings triage, SLA tracking, vulnerability inventory
- Webhooks
- **AI Summary** (via Ollama)

For paid features (scheduling, policies, compliance, **AI remediation & validation**, integrations), request a license key at **sales@dyallab.com.ar**.

## Updating

```bash
docker compose pull
docker compose up -d
```

Migrations run automatically on startup. See the [deployment guide](https://henkaipan.dyallab.com.ar/docs/quickstart/#updating) for rollback procedures.

## Production Checklist

- [ ] Set `COOKIE_SECURE=true` (REQUIRED behind HTTPS)
- [ ] Set `COOKIE_DOMAIN=.example.com` for your domain
- [ ] Set `COOKIE_SAMESITE=lax` (default) or `strict` for stricter CSRF protection
- [ ] Set `CORS_ALLOWED_ORIGINS=https://aspm.example.com` (comma-separated if multiple)
- [ ] Configure reverse proxy (nginx/caddy/traefik) with TLS termination
- [ ] Set `PUBLIC_API_BASE=` (empty) in frontend, or serve API + frontend from same origin
- [ ] Set up database backups
- [ ] Configure email notifications (SMTP)
- [ ] Rotate default credentials (`ADMIN_USER`, `ADMIN_PASS`, `JWT_SECRET`, `SECRET_ENCRYPTION_KEY`)

## Security

HenKaiPan follows **defense-in-depth** principles. All services are hardened by default:

| Layer | Implementation |
|-------|---------------|
| **Syscall** | seccomp profiles restrict allowed system calls |
| **Capabilities** | `cap_drop ALL` + minimal `cap_add` per service |
| **Privileges** | `no-new-privileges` on all services |
| **User** | Non-root user (1000:1000) on worker |
| **Filesystem** | Read-only root filesystem (Kubernetes) |
| **Network** | Isolated bridge network, no Docker socket |

### Service Capabilities

| Service | cap_drop | cap_add |
|---------|----------|---------|
| **postgres** | ALL | CHOWN, SETUID, SETGID, DAC_OVERRIDE |
| **redis** | ALL | CHOWN, SETUID, SETGID |
| **worker** | ALL | FOWNER, FSETID, DAC_OVERRIDE, CHOWN, SETUID, SETGID |
| **api** | ALL | — (none needed) |

### Scanner Execution

Worker runs scanners as **binaries** via `os/exec` — no Docker socket required.
Supported scanners: semgrep, trivy, gitleaks, checkov, grype, osv-scanner, trufflehog, tfsec, kics, nuclei, gosec.

### Rate Limiting

Redis-based rate limiting is enabled by default with per-endpoint tiers:
- Auth endpoints: 10 requests/min
- Heavy operations: 20 requests/min
- General endpoints: 100 requests/min

Rate limit headers (`X-RateLimit-*`) are included in responses.
The system **fails closed** on Redis errors (requests blocked for safety).

### Security Headers

All API responses include:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Content-Security-Policy: default-src 'self'`
- `Strict-Transport-Security` (when `COOKIE_SECURE=true`)

### Input Validation

All API inputs are validated:
- **Backend**: go-playground/validator enforces field constraints
- **Frontend**: Zod schemas provide client-side validation
- Invalid requests return `400` with detailed error messages

### Reverse Proxy Example (nginx)

When deploying behind a reverse proxy, the API and frontend should be served
from the **same origin** (e.g. `https://aspm.example.com`). This eliminates
CORS issues and ensures cookies work correctly.

```nginx
server {
    listen 443 ssl http2;
    server_name aspm.example.com;

    ssl_certificate     /etc/ssl/aspm.crt;
    ssl_certificate_key /etc/ssl/aspm.key;

    # Frontend (static files)
    location / {
        proxy_pass http://127.0.0.1:4321;
    }

    # API + SSE
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # SSE-specific: disable buffering for real-time events
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

For detailed production deployment instructions, see the [production deployment guide](https://henkaipan.dyallab.com.ar/docs/quickstart/#production-deployment).

## Support

- **Documentation**: https://henkaipan.dyallab.com.ar/docs/
- **Sales & Licensing**: sales@dyallab.com.ar
- **GitHub Issues**: Report bugs or feature requests
