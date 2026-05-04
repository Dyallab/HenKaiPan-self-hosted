#!/usr/bin/env bash
set -eEuo pipefail
test "${DEBUG:-}" && set -x

# ──────────────────────────────────────────────────────────
# HenKaiPan ASPM — Self-Hosted Installer
# ──────────────────────────────────────────────────────────
# Usage: ./install.sh
#
# Checks prerequisites, generates config, pre-pulls images,
# and prints next steps.
#
# Inspired by: https://github.com/getsentry/self-hosted

# Override any user-supplied umask that could cause problems
umask 002

# Error handling - cleanup on exit
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo ""
    fail "Installation failed with exit code $exit_code"
    echo "  Check logs above for details."
    echo "  You can re-run this script after fixing the issue."
  fi
  exit $exit_code
}
trap_with_arg() {
  func="$1" ; shift
  for sig ; do
    trap "$func $sig" "$sig"
  done
}
trap_with_arg cleanup ERR INT TERM EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e " ${GREEN}✓${NC} $1"; }
warn() { echo -e " ${YELLOW}⚠${NC} $1"; }
fail() { echo -e " ${RED}✗${NC} $1"; }
info() { echo -e " ${CYAN}→${NC} $1"; }
step() { echo -e "${BOLD}${CYAN}▶ $1${NC}"; }

echo ""
echo "  ${BOLD}HenKaiPan ASPM — Self-Hosted Installer${NC}"
echo "  ======================================"
echo ""

# ── Pre-flight checks ────────────────────────────────────

step "Pre-flight checks"
echo ""

info "Checking prerequisites..."

# Check if running in MSYS2 (Git Bash on Windows)
if [[ -n "${MSYSTEM:-}" ]]; then
  fail "Running in MSYS2/Git Bash is not supported. Please use WSL2 instead."
fi

command -v docker >/dev/null 2>&1 || fail "Docker is not installed. Install Docker first: https://docs.docker.com/get-docker/"
ok "Docker found: $(docker --version 2>/dev/null | head -1)"

command -v docker compose >/dev/null 2>&1 || fail "Docker Compose v2 is not installed. Install Docker Desktop or docker-compose plugin."
ok "Docker Compose found: $(docker compose version 2>/dev/null | head -1)"

# Minimum Docker Compose v2.24
COMPOSE_VERSION=$(docker compose version --short 2>/dev/null | sed 's/v//')
if [ "$(printf '%s\n' "2.24" "$COMPOSE_VERSION" | sort -V | head -1)" != "2.24" ]; then
  warn "Docker Compose $COMPOSE_VERSION may be too old. v2.24+ recommended for healthcheck support."
else
  ok "Docker Compose $COMPOSE_VERSION (v2.24+ OK)"
fi

# Check if user can run docker without sudo
if docker ps >/dev/null 2>&1; then
  ok "Docker permissions OK"
else
  warn "Cannot run 'docker ps' without sudo. You may need to:"
  echo "    1. Add your user to the 'docker' group: sudo usermod -aG docker \$USER"
  echo "    2. Log out and back in"
  echo "    3. Or run this script with sudo"
fi

# Check RAM (Linux only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  TOTAL_RAM=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo 0)
  if [ "$TOTAL_RAM" -gt 0 ] && [ "$TOTAL_RAM" -lt 8 ]; then
    fail "System has only ${TOTAL_RAM} GB RAM. 8 GB minimum required (16 GB recommended)."
  elif [ "$TOTAL_RAM" -gt 0 ]; then
    ok "${TOTAL_RAM} GB RAM detected"
  fi
fi

# Check disk space
AVAIL_DISK=$(df -BG --output=avail /var/lib/docker 2>/dev/null | tail -1 | tr -d 'G' || echo 0)
if [ "$AVAIL_DISK" -gt 0 ] && [ "$AVAIL_DISK" -lt 30 ]; then
  fail "Only ${AVAIL_DISK} GB free on Docker storage. 30 GB minimum required."
elif [ "$AVAIL_DISK" -gt 0 ]; then
  ok "${AVAIL_DISK} GB free disk space"
fi

# Check architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64|amd64)
    ok "Architecture: $ARCH (supported)"
    ;;
  aarch64|arm64)
    ok "Architecture: $ARCH (supported)"
    warn "ARM64 detected. Some images may need to be built from source."
    ;;
  *)
    warn "Architecture: $ARCH (unknown - may have compatibility issues)"
    ;;
esac

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

step "Installation complete!"
echo ""

# Try to get the admin password from .env if it exists
ADMIN_DISPLAY=""
if [ -f ".env" ]; then
  ADMIN_DISPLAY=$(grep "^ADMIN_PASS=" .env 2>/dev/null | cut -d'=' -f2 | head -1)
fi

if [ -n "$ADMIN_DISPLAY" ]; then
  echo "  ┌─────────────────────────────────────────────────────┐"
  echo "  │  ${GREEN}Installation complete${NC}                                     │"
  echo "  │                                                     │"
  echo "  │  Run the stack:                                     │"
  echo "  │    ${CYAN}docker compose up -d${NC}                              │"
  echo "  │                                                     │"
  echo "  │  Open:    ${CYAN}http://localhost:8080${NC}                      │"
  echo "  │  Login:   admin / ${YELLOW}$ADMIN_DISPLAY${NC}                       │"
  echo "  │                                                     │"
  echo "  │  ${YELLOW}⚠ Change the default password after first login!${NC}   │"
  echo "  │                                                     │"
  echo "  │  For production:                                    │"
  echo "  │    - Set COOKIE_SECURE=true behind HTTPS             │"
  echo "  │    - Configure reverse proxy (nginx/caddy) with TLS  │"
  echo "  │    - Set up database backups (see docs/)             │"
  echo "  │    - Review security checklist in README.md          │"
  echo "  │                                                     │"
  echo "  │  Documentation: https://henkaipan.dyallab.com.ar    │"
  echo "  └─────────────────────────────────────────────────────┘"
else
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
  echo "  │    - Set up database backups (see docs/)             │"
  echo "  │    - Review security checklist in README.md          │"
  echo "  │                                                     │"
  echo "  │  Documentation: https://henkaipan.dyallab.com.ar    │"
  echo "  └─────────────────────────────────────────────────────┘"
fi
echo ""
