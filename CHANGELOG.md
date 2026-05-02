# Changelog

All notable changes to the self-hosted distribution are documented here.

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
