#!/usr/bin/env bash
# install-wazuh-agent.sh — Installs Wazuh 4.x agent and points it at the manager.
# Idempotent: safe to run more than once.
#
# Usage:
#   export WAZUH_MANAGER=YOUR_WAZUH_MANAGER_IP
#   sudo bash install-wazuh-agent.sh
set -euo pipefail

: "${WAZUH_MANAGER:?\u274c WAZUH_MANAGER env var is required. Export it before running.}"

echo "==> [1/4] Adding Wazuh 4.x apt repository..."
if [ ! -f /usr/share/keyrings/wazuh.gpg ]; then
  curl -fsSL https://packages.wazuh.com/key/GPG-KEY-WAZUH \
    | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
  echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] \
https://packages.wazuh.com/4.x/apt/ stable main" \
    | tee /etc/apt/sources.list.d/wazuh.list > /dev/null
  apt-get update -qq
else
  echo "    Wazuh repo already configured — skipping."
fi

echo "==> [2/4] Installing wazuh-agent..."
if dpkg -s wazuh-agent &>/dev/null; then
  echo "    wazuh-agent already installed — skipping package install."
else
  WAZUH_MANAGER="${WAZUH_MANAGER}" \
  WAZUH_MANAGER_PORT="1514" \
  WAZUH_PROTOCOL="TCP" \
  WAZUH_AGENT_NAME="$(hostname)" \
    apt-get install -y wazuh-agent
fi

echo "==> [3/4] Ensuring manager address is set in ossec.conf..."
OSSEC_CONF="/var/ossec/etc/ossec.conf"
if grep -q "<address>${WAZUH_MANAGER}</address>" "$OSSEC_CONF"; then
  echo "    Manager address already correct."
else
  sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|" "$OSSEC_CONF"
  echo "    Updated manager address to ${WAZUH_MANAGER}"
fi

echo "==> [4/4] Enabling and starting wazuh-agent..."
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl restart wazuh-agent

echo ""
echo "\u2705 Wazuh agent installed and pointing to manager: ${WAZUH_MANAGER}"
echo "   Verify: sudo systemctl status wazuh-agent"
