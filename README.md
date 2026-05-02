# HenKaiPan ASPM — Self-Hosted

Application Security Posture Management platform. Self-hosted edition.

## Prerequisites

- **Docker** & **Docker Compose** (v2.24+)
- **8 GB RAM** minimum (16 GB recommended for concurrent scans)
- **30 GB free disk** — scanner images are ~6 GB, plus app images and data

## Quickstart

```bash
# 1. Configure
cp .env.example .env
# Edit .env: set JWT_SECRET, SECRET_ENCRYPTION_KEY, ADMIN_PASS

# 2. Start
docker compose up -d

# 3. Open http://localhost:8080
#    Login with admin / <ADMIN_PASS>
```

## Configuration

See `.env.example` for all options. Required variables:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Auth token signing key |
| `SECRET_ENCRYPTION_KEY` | Encryption key for stored secrets |
| `ADMIN_PASS` | Default admin password |

## License Key

The app runs in **free mode** without a license key — no time limit. Features available:

- Unlimited projects & users
- All scanners (SAST, SCA, Secrets, IaC, Containers)
- Findings triage, SLA tracking, vulnerability inventory
- Webhooks

For paid features (scheduling, policies, compliance, AI remediation, integrations), request a license key at **sales@henkaipan.dev**.

## Updating

```bash
docker compose pull
docker compose up -d
```

## Production Checklist

- [ ] Set `COOKIE_SECURE=true` behind HTTPS
- [ ] Configure reverse proxy (nginx/caddy) with TLS
- [ ] Set up database backups
- [ ] Configure email notifications (SMTP)
