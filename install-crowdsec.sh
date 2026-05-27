#!/usr/bin/env bash
# install-crowdsec.sh — Installs CrowdSec + firewall bouncer on the host.
# Idempotent: safe to run more than once.
set -euo pipefail

echo "==> [1/5] Installing CrowdSec repository..."
if ! command -v crowdsec &>/dev/null; then
  curl -fsSL https://packagecloud.io/crowdsec/crowdsec/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/crowdsec-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/crowdsec-archive-keyring.gpg] \
https://packagecloud.io/crowdsec/crowdsec/ubuntu/ \$(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/crowdsec.list > /dev/null
  apt-get update -qq
  apt-get install -y crowdsec
else
  echo "    CrowdSec already installed — skipping package install."
fi

echo "==> [2/5] Configuring CrowdSec LAPI listen address (0.0.0.0:8095)..."
CONFIG_FILE="/etc/crowdsec/config.yaml"
if grep -q "listen_uri: 0.0.0.0:8095" "\$CONFIG_FILE"; then
  echo "    listen_uri already set."
else
  sed -i 's|listen_uri:.*|listen_uri: 0.0.0.0:8095|' "\$CONFIG_FILE"
  echo "    listen_uri updated to 0.0.0.0:8095"
fi

echo "==> [3/5] Installing CrowdSec collections..."
cscli collections install crowdsecurity/traefik   || true
cscli collections install crowdsecurity/linux      || true

echo "==> [4/5] Installing crowdsec-firewall-bouncer-iptables..."
if ! command -v crowdsec-firewall-bouncer &>/dev/null; then
  apt-get install -y crowdsec-firewall-bouncer-iptables
else
  echo "    crowdsec-firewall-bouncer-iptables already installed — skipping."
fi

echo "==> [5/5] Enabling and restarting services..."
systemctl enable crowdsec
systemctl restart crowdsec
systemctl enable crowdsec-firewall-bouncer
systemctl restart crowdsec-firewall-bouncer

echo ""
echo "✅ CrowdSec installation complete."
echo "   Next: register the Traefik bouncer API key:"
echo "   sudo cscli bouncers add traefik-bouncer"
