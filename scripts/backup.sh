#!/usr/bin/env bash
set -euo pipefail

# HenKaiPan ASPM — Database Backup Script
# Supports Docker Compose and Kubernetes deployments.

BACKUP_DIR="${BACKUP_DIR:-$(dirname "$0")/../backups}"
TIMESTAMP=$(date +%Y-%m-%dT%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/aspm-backup-${TIMESTAMP}.sql"

# ── Detect deployment mode ──────────────────────────────────────────

detect_mode() {
    if [ -f "$(dirname "$0")/../docker-compose.yml" ]; then
        echo "docker"
    elif command -v kubectl &>/dev/null && kubectl get pods -l app=henkaipan-postgres -o name 2>/dev/null | grep -q .; then
        echo "kubernetes"
    else
        echo "unknown"
    fi
}

# ── Docker Compose backup ───────────────────────────────────────────

backup_docker() {
    local db_url_var="${1:-}"
    mkdir -p "$BACKUP_DIR"

    echo "HenKaiPan ASPM Backup"
    echo "====================="
    echo ""
    echo "Mode: Docker Compose"

    docker compose exec -T postgres pg_dump -U aspm -d aspm > "$BACKUP_FILE"

    echo ""
    echo "✓ Backup completed successfully!"
    echo "  File: $BACKUP_FILE"
    echo "  Size: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo ""
    echo "To restore this backup:"
    echo "  docker compose exec -T postgres psql -U aspm -d aspm < $BACKUP_FILE"
}

# ── Kubernetes backup ───────────────────────────────────────────────

backup_kubernetes() {
    mkdir -p "$BACKUP_DIR"

    local pod
    pod=$(kubectl get pods -l app=henkaipan-postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$pod" ]; then
        echo "Error: Could not find postgres pod. Check kubectl context and labels."
        exit 1
    fi

    echo "HenKaiPan ASPM Backup"
    echo "====================="
    echo ""
    echo "Mode: Kubernetes"
    echo "Pod:  $pod"

    kubectl exec "$pod" -- pg_dump -U aspm -d aspm > "$BACKUP_FILE"

    echo ""
    echo "✓ Backup completed successfully!"
    echo "  File: $BACKUP_FILE"
    echo "  Size: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo ""
    echo "To restore this backup:"
    echo "  kubectl exec -i $pod -- psql -U aspm -d aspm < $BACKUP_FILE"
}

# ── Main ────────────────────────────────────────────────────────────

main() {
    local mode
    mode=$(detect_mode)

    case "$mode" in
        docker)     backup_docker ;;
        kubernetes) backup_kubernetes ;;
        *)
            echo "Error: Could not detect deployment mode (docker or kubernetes)."
            echo ""
            echo "Run this script from the HenKaiPan-self-hosted directory,"
            echo "or ensure kubectl is configured with the correct context."
            exit 1
            ;;
    esac
}

main
