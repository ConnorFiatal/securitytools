#!/usr/bin/env bash
# crowdsec-wazuh-bridge.sh — Configures CrowdSec HTTP notifications to forward
# alerts to the local Wazuh agent syslog input on UDP port 514.
# The Wazuh agent then relays them to the manager on port 1514.
# Idempotent: safe to run more than once.
set -euo pipefail

NOTIFICATION_DIR="/etc/crowdsec/notifications"
PROFILE_FILE="/etc/crowdsec/profiles.yaml"
NOTIF_FILE="${NOTIFICATION_DIR}/http.yaml"

echo "==> [1/3] Writing CrowdSec HTTP notification plugin config..."
mkdir -p "$NOTIFICATION_DIR"

cat > "$NOTIF_FILE" << 'NOTIFEOF'
# CrowdSec HTTP notification -> forwards alerts to local syslog (Wazuh agent)
type: http
name: wazuh_http_notifier
log_level: info

# Sends a JSON POST to the local Wazuh agent syslog receiver
url: http://127.0.0.1:514

format: |
  {
    "program": "crowdsec",
    "level": "warning",
    "scenario": "{{.Scenario}}",
    "src_ip": "{{.Source.IP}}",
    "action": "{{.Decisions | toJson}}",
    "timestamp": "{{.StartAt}}"
  }

headers:
  Content-Type: "application/json"

timeout: 5s
NOTIFEOF

echo "    Written: ${NOTIF_FILE}"

echo "==> [2/3] Adding Wazuh notifier to CrowdSec profiles.yaml (if not present)..."
if grep -q "wazuh_http_notifier" "$PROFILE_FILE"; then
  echo "    Profile entry already present — skipping."
else
  cat >> "$PROFILE_FILE" << 'PROFILEEOF'

# --- Wazuh bridge: forward all decisions to local Wazuh agent ---
name: wazuh_forward
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
notifications:
  - wazuh_http_notifier
on_success: continue
PROFILEEOF
  echo "    Profile entry added."
fi

echo "==> [3/3] Restarting CrowdSec to apply changes..."
systemctl restart crowdsec

echo ""
echo "✅ CrowdSec -> Wazuh bridge configured."
echo "   Verify: sudo cscli notifications list"
echo "   Verify: sudo cscli notifications test wazuh_http_notifier"
