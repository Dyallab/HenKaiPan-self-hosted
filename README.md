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

## Support

- **Documentation**: https://henkaipan.dyallab.com.ar/docs/
- **Email**: henkaipan@dyallab.com.ar
- **GitHub Issues**: [Report bugs or feature requests](https://github.com/Dyallab/HenKaiPan-self-hosted/issues)
