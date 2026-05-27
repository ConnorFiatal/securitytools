#!/usr/bin/env bash
# install-wazuh-manager-docker.sh — Deploys Wazuh single-node stack via Docker Compose.
# Idempotent: safe to run more than once.
#
# Requires: docker, docker compose (v2), git, openssl
# Run on your dedicated Wazuh VPS (or the same host if resources allow).
set -euo pipefail

WAZUH_VERSION="v4.14.5"
REPO_DIR="${HOME}/wazuh-docker"
REQUIRED_PORTS=(443 9200 1514 1515)

echo "==> [1/6] Checking required dependencies..."
for cmd in docker git openssl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required command not found: $cmd — please install it first."
    exit 1
  fi
done
if ! docker compose version &>/dev/null; then
  echo "❌ docker compose (v2 plugin) not found. Install docker-compose-plugin."
  exit 1
fi
echo "    All dependencies present."

echo "==> [2/6] Checking that required ports are free..."
for port in "${REQUIRED_PORTS[@]}"; do
  if ss -tlnp | grep -q ":${port} "; then
    echo "❌ Port ${port} is already in use. Free it before continuing."
    exit 1
  fi
done
echo "    Ports 443, 9200, 1514, 1515 are all free."

echo "==> [3/6] Cloning wazuh-docker repo at ${WAZUH_VERSION}..."
if [ -d "$REPO_DIR" ]; then
  echo "    Repo already cloned at ${REPO_DIR}."
  cd "$REPO_DIR"
  git fetch --tags
  git checkout "${WAZUH_VERSION}"
else
  git clone --branch "${WAZUH_VERSION}" \
    https://github.com/wazuh/wazuh-docker.git "$REPO_DIR"
  cd "$REPO_DIR"
fi

echo "==> [4/6] Entering single-node directory..."
cd "${REPO_DIR}/single-node"

echo "==> [5/6] Generating TLS certificates..."
if [ -f "config/wazuh_indexer_ssl_certs/root-ca.pem" ]; then
  echo "    Certificates already exist — skipping cert generation."
else
  docker compose -f generate-indexer-certs.yml run --rm generator
  echo "    Certificates generated."
fi

echo "==> [6/6] Starting Wazuh single-node stack..."
docker compose up -d

echo ""
echo "✅ Wazuh manager stack started."
echo "   Dashboard: https://$(curl -s ifconfig.me)"
echo "   Default credentials: admin / SecretPassword (change immediately!)"
echo "   Check status: docker compose -C ${REPO_DIR}/single-node ps"
