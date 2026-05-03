# HenKaiPan ASPM — Self-Hosted

Application Security Posture Management platform. Self-hosted edition.

📚 **Documentation**: [Quickstart](https://henkaipan.dyallab.com.ar/docs/quickstart/) | [Licensing](https://henkaipan.dyallab.com.ar/docs/licensing/) | [Backup & Restore](https://henkaipan.dyallab.com.ar/docs/backup/)

## Prerequisites

- **Docker** & **Docker Compose** (v2.24+)
- **8 GB RAM** minimum (16 GB recommended for concurrent scans)
- **30 GB free disk** — scanner images are ~6 GB, plus app images and data

## Quickstart

```bash
# 1. Run the installer (checks prerequisites, generates secrets)
./install.sh

# 2. Start
docker compose up -d

# 3. Open http://localhost:8080
#    Login with admin / <your password>
```

### Manual setup (without install.sh)

```bash
cp .env.example .env
# Edit .env: set JWT_SECRET, SECRET_ENCRYPTION_KEY, ADMIN_PASS
docker compose up -d
```

## Configuration

See `.env.example` for all options. Required variables:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Auth token signing key |
| `SECRET_ENCRYPTION_KEY` | Encryption key for stored secrets |
| `ADMIN_PASS` | Default admin password |

### AI Providers

The self-hosted edition supports multiple AI providers for remediation, summary, and validation tasks:

- **Ollama** (FREE, self-hosted) — Default. Set `OLLAMA_URL` and `OLLAMA_MODEL`
- **OpenRouter** (Paid) — Highest quality models. Set `OPENROUTER_API_KEY`
- **Cloudflare Workers AI** (Paid) — Cost-effective. Set `CF_ACCOUNT_ID` and `CF_API_TOKEN`

Configure providers per task using `AI_REMEDIATION_PROVIDER`, `AI_SUMMARY_PROVIDER`, and `AI_VALIDATION_PROVIDER`.

### Monitoring

Prometheus metrics are exposed on port `9090` (configurable via `PROMETHEUS_PORT`). Includes queue and database metrics collectors.

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

For paid features (scheduling, policies, compliance, AI remediation, integrations), request a license key at **sales@dyallab.com.ar**.

## Updating

```bash
docker compose pull
docker compose up -d
```

Migrations run automatically on startup. See the [deployment guide](https://henkaipan.dyallab.com.ar/docs/quickstart/#updating) for rollback procedures.

## Production Checklist

- [ ] Set `COOKIE_SECURE=true` behind HTTPS
- [ ] Configure reverse proxy (nginx/caddy) with TLS
- [ ] Set up database backups
- [ ] Configure email notifications (SMTP)

For detailed production deployment instructions, see the [production deployment guide](https://henkaipan.dyallab.com.ar/docs/quickstart/#production-deployment).

## Support

- **Documentation**: https://henkaipan.dyallab.com.ar/docs/
- **Sales & Licensing**: sales@dyallab.com.ar
- **GitHub Issues**: Report bugs or feature requests
