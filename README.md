# Wazuh + CrowdSec Security Stack

> Hardening config for a Coolify/Traefik server running a Node.js web app on Ubuntu.

## What Each Tool Does

**CrowdSec** is a collaborative, open-source intrusion prevention system. It reads
your log files, detects attack patterns (brute-force SSH, bad HTTP bots, scanners),
and issues decisions (bans). Bouncers enforce those decisions:

- The **firewall bouncer** drops malicious IPs at the iptables level, protecting SSH and all other services.
- The **Traefik bouncer plugin** checks incoming HTTP requests against the CrowdSec LAPI before they reach your Node.js app.

**Wazuh** is an open-source security monitoring platform. The agent runs on your
Coolify host, ships logs and file-integrity events to the manager, which correlates
them against thousands of security rules (including CVE detection for Docker images).

---

## File Map

| File | Purpose | Destination on server |
|---|---|---|
| `install-crowdsec.sh` | Installs CrowdSec + firewall bouncer | Run from any directory as root |
| `crowdsec-acquis.yaml` | Tells CrowdSec which logs to watch | `/etc/crowdsec/acquis.d/custom-acquis.yaml` |
| `crowdsec-plugin.yaml` | Traefik middleware config (HTTP bouncer) | `/data/coolify/proxy/dynamic/crowdsec-plugin.yaml` |
| `traefik-plugin-patch.yaml` | Loads bouncer plugin in Traefik static config | Pasted via Coolify UI |
| `install-wazuh-agent.sh` | Installs Wazuh 4.x agent | Run on the Coolify host as root |
| `wazuh-ossec-additions.xml` | Adds Docker listener + syscheck rules | Appended to `/var/ossec/etc/ossec.conf` |
| `install-wazuh-manager-docker.sh` | Deploys Wazuh manager (Docker, single-node) | Run on Wazuh VPS as root |
| `crowdsec-wazuh-bridge.sh` | Forwards CrowdSec alerts to Wazuh agent | Run on Coolify host as root |
| `SETUP-CHECKLIST.md` | Step-by-step run order with verify commands | Reference only |
| `README.md` | This file | Reference only |

---

## Architecture

```
Internet
    |
    v
[Traefik v3]  <-- crowdsec-plugin.yaml (middleware: bouncer@file)
    |                      |
    |              [CrowdSec LAPI :8095]
    |                      |
    v               +------+-------+
[Node.js App]  [firewall-bouncer]  [Wazuh Agent]
(Docker)       (iptables rules)        |
                                       | TCP 1514
                                  [Wazuh Manager]
                                  (Docker / VPS)
                                       |
                                  [OpenSearch]
                                  [Dashboard :443]
```

---

## Useful Operational Commands

| Task | Command |
|---|---|
| List active CrowdSec bans | `sudo cscli decisions list` |
| Manually ban an IP | `sudo cscli decisions add --ip <IP> --reason "manual" --duration 24h` |
| Remove a ban | `sudo cscli decisions delete --ip <IP>` |
| View CrowdSec alerts | `sudo cscli alerts list` |
| Check bouncer status | `sudo cscli bouncers list` |
| CrowdSec service logs | `sudo journalctl -u crowdsec -f` |
| Firewall bouncer logs | `sudo journalctl -u crowdsec-firewall-bouncer -f` |
| Wazuh agent status | `sudo systemctl status wazuh-agent` |
| Wazuh agent logs | `sudo tail -f /var/ossec/logs/ossec.log` |
| Wazuh manager stack status | `docker compose -C ~/wazuh-docker/single-node ps` |
| Wazuh dashboard | `https://YOUR_WAZUH_MANAGER_IP` (admin / SecretPassword) |
| Traefik dashboard | Via Coolify UI > Servers > Proxy |
| Reload CrowdSec config | `sudo systemctl reload crowdsec` |
| Test a notifier | `sudo cscli notifications test wazuh_http_notifier` |
| Update CrowdSec hub rules | `sudo cscli hub update && sudo cscli hub upgrade` |

---

## Security Notes

- **Change the Wazuh dashboard default password** (`admin` / `SecretPassword`) immediately after first login.
- Keep `YOUR_BOUNCER_API_KEY` secret — it grants full read/write access to the CrowdSec LAPI.
- Firewall: ensure port **8095** (CrowdSec LAPI) is **not** publicly reachable.
- Wazuh manager ports **1514** and **1515** should only be reachable from your Coolify host IP.
- All shell scripts are idempotent — safe to re-run if a step needs to be repeated.
