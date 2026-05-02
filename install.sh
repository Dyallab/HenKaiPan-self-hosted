#!/usr/bin/env bash
set -eEuo pipefail

# ──────────────────────────────────────────────────────────
# HenKaiPan ASPM — Self-Hosted Installer
# ──────────────────────────────────────────────────────────
# Usage: ./install.sh
#
# Checks prerequisites, generates config, pre-pulls images,
# and prints next steps.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e " ${GREEN}✓${NC} $1"; }
warn() { echo -e " ${YELLOW}⚠${NC} $1"; }
fail() { echo -e " ${RED}✗${NC} $1"; exit 1; }
info() { echo -e " ${CYAN}→${NC} $1"; }

echo ""
echo "  HenKaiPan ASPM — Self-Hosted Installer"
echo "  ======================================"
echo ""

# ── Prerequisites ────────────────────────────────────────

info "Checking prerequisites..."

command -v docker >/dev/null 2>&1 || fail "Docker is not installed."
ok "Docker found: $(docker --version 2>/dev/null)"

command -v docker compose >/dev/null 2>&1 || fail "Docker Compose v2 is not installed."
ok "Docker Compose found: $(docker compose version 2>/dev/null)"

# Minimum Docker Compose v2.24
COMPOSE_VERSION=$(docker compose version --short 2>/dev/null | sed 's/v//')
if [ "$(printf '%s\n' "2.24" "$COMPOSE_VERSION" | sort -V | head -1)" != "2.24" ]; then
  warn "Docker Compose $COMPOSE_VERSION may be too old. v2.24+ recommended for healthcheck support."
else
  ok "Docker Compose $COMPOSE_VERSION (v2.24+ OK)"
fi

# Check RAM (Linux only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  TOTAL_RAM=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 0)
  if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 8 ]; then
    warn "System has ${TOTAL_RAM} GB RAM. 8 GB minimum recommended (16 GB for concurrent scans)."
  elif [ "$TOTAL_RAM" -gt 0 ]; then
    ok "${TOTAL_RAM} GB RAM detected"
  fi
fi

# Check disk
AVAIL_DISK=$(df --output=avail /var/lib/docker 2>/dev/null | tail -1 || echo 0)
if [ "$AVAIL_DISK" -gt 0 ] && [ "$AVAIL_DISK" -lt 30 ]; then
  warn "Only ${AVAIL_DISK} GB free on Docker storage. 30 GB recommended."
fi

echo ""

# ── Configuration ────────────────────────────────────────

if [ -f ".env" ]; then
  info ".env already exists — skipping configuration."
else
  info "Generating .env file..."

  JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c 64)
  ENC_KEY=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-f0-9' | head -c 64)

  ADMIN_PASS=""
  while [ -z "$ADMIN_PASS" ]; do
    read -s -p "  Admin password (leave empty for random): " ADMIN_PASS_INPUT
    echo ""
    if [ -z "$ADMIN_PASS_INPUT" ]; then
      ADMIN_PASS=$(openssl rand -base64 12 2>/dev/null || echo "change-me")
      info "Generated random admin password: ${ADMIN_PASS}"
      echo "  (save this somewhere safe)"
    else
      ADMIN_PASS="$ADMIN_PASS_INPUT"
    fi
  done

  cp .env.example .env

  # macOS sed vs Linux sed
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
    sed -i '' "s|SECRET_ENCRYPTION_KEY=.*|SECRET_ENCRYPTION_KEY=${ENC_KEY}|" .env
    sed -i '' "s|ADMIN_PASS=.*|ADMIN_PASS=${ADMIN_PASS}|" .env
  else
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=${JWT_SECRET}|" .env
    sed -i "s|SECRET_ENCRYPTION_KEY=.*|SECRET_ENCRYPTION_KEY=${ENC_KEY}|" .env
    sed -i "s|ADMIN_PASS=.*|ADMIN_PASS=${ADMIN_PASS}|" .env
  fi

  ok ".env configured"
fi

echo ""

# ── Pre-pull images ──────────────────────────────────────

info "Pre-pulling Docker images (this may take a few minutes)..."

IMAGES=$(docker compose config --images 2>/dev/null || true)
if [ -n "$IMAGES" ]; then
  echo "$IMAGES" | while read -r IMG; do
    [ -z "$IMG" ] && continue
    info "Pulling ${IMG}..."
    docker pull "$IMG" >/dev/null 2>&1 &
  done
  wait
  ok "Images pulled"
else
  warn "Could not determine images to pull. Run 'docker compose pull' manually."
fi

echo ""

# ── Summary ───────────────────────────────────────────────

echo ""
echo "  ┌─────────────────────────────────────────────────────┐"
echo "  │  ${GREEN}Installation complete${NC}                                     │"
echo "  │                                                     │"
echo "  │  Run the stack:                                     │"
echo "  │    ${CYAN}docker compose up -d${NC}                              │"
echo "  │                                                     │"
echo "  │  Open:    ${CYAN}http://localhost:8080${NC}                      │"
echo "  │  Login:   admin / <your password>                    │"
echo "  │                                                     │"
echo "  │  For production:                                    │"
echo "  │    - Set COOKIE_SECURE=true behind HTTPS             │"
echo "  │    - Configure reverse proxy (nginx/caddy) with TLS  │"
echo "  │    - Set up database backups                         │"
echo "  │                                                     │"
echo "  └─────────────────────────────────────────────────────┘"
echo ""
