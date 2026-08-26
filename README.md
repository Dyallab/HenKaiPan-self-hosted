# HenKaiPan ASPM — Self-Hosted

Application Security Posture Management platform. Self-hosted edition.

📚 **Full documentation**: [henkaipan.dyallab.com.ar/docs](https://henkaipan.dyallab.com.ar/docs/)

## Quickstart

```bash
# 1. Run the installer (pulls images, generates secrets, starts the stack)
./install.sh                 # with Ollama (free AI summaries)
./install.sh --skip-ollama   # without Ollama
```

## Kubernetes

See [Kubernetes Deployment Guide](https://henkaipan.dyallab.com.ar/docs/self-hosted/kubernetes/).

## Documentation

| Guide | |
|-------|------|
| [Quickstart](https://henkaipan.dyallab.com.ar/docs/quickstart/) | Getting started, configuration, AI providers, rate limiting |
| [Production Deployment](https://henkaipan.dyallab.com.ar/docs/self-hosted/production/) | TLS, security hardening, environment variables, production checklist, monitoring, backups |
| [Backup & Restore](https://henkaipan.dyallab.com.ar/docs/backup/) | Automated and manual backup procedures |
| [Operations](https://henkaipan.dyallab.com.ar/docs/self-hosted/operations/) | Worker scaling, scanner requirements, troubleshooting |
| [Kubernetes](https://henkaipan.dyallab.com.ar/docs/self-hosted/kubernetes/) | K8s production deployment |
| [SSO with Authelia](https://henkaipan.dyallab.com.ar/docs/sso-authelia/) | Single sign-on via OIDC (Authelia, Keycloak, Google, etc.) |

## Support

- **Documentation**: https://henkaipan.dyallab.com.ar/docs/
- **Email**: henkaipan@dyallab.com.ar
- **GitHub Issues**: [Report bugs or feature requests](https://github.com/Dyallab/HenKaiPan-self-hosted/issues)

## License

This repository (deployment config, installer scripts, and documentation) is
released under the **MIT License** — see [LICENSE](LICENSE).

The HenKaiPan application images referenced here are built from the
[HenKaiPan-app](https://github.com/Dyallab/HenKaiPan) codebase, which is
licensed under the **Business Source License 1.1**. Self-hosted use of the
software is free and unrestricted. For Cloud / Enterprise hosting managed by
Dyallab, contact henkaipan@dyallab.com.ar.
