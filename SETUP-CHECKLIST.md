# Security Setup Checklist

Work through these steps **in order**. Each step references the file to run and
what to verify before moving on.

---

## Prerequisites

- [ ] You are logged into the Coolify host as root (or a user with `sudo`).
- [ ] Traefik is running and serving your Node.js app.
- [ ] (If using a separate VPS for Wazuh) You have SSH access to that VPS.

---

## Step 1 — Install CrowdSec on the host

**File:** `install-crowdsec.sh`

```bash
sudo bash install-crowdsec.sh
```

**Verify:**
```bash
sudo systemctl status crowdsec
sudo systemctl status crowdsec-firewall-bouncer
sudo cscli collections list   # should show traefik + linux collections
```

---

## Step 2 — Deploy log acquisition config

**File:** `crowdsec-acquis.yaml`

```bash
sudo cp crowdsec-acquis.yaml /etc/crowdsec/acquis.d/custom-acquis.yaml
sudo systemctl restart crowdsec
```

**Verify:**
```bash
sudo cscli metrics   # check "Acquisition" section shows auth.log, syslog, traefik
```

---

## Step 3 — Generate the Traefik bouncer API key

> ⚠️ MANUAL STEP — run this command and **copy the printed key**:

```bash
sudo cscli bouncers add traefik-bouncer
```

Open `crowdsec-plugin.yaml` and replace `YOUR_BOUNCER_API_KEY` with the key printed above.

---

## Step 4 — Deploy the Traefik dynamic middleware

**File:** `crowdsec-plugin.yaml` *(after editing in Step 3)*

```bash
sudo cp crowdsec-plugin.yaml /data/coolify/proxy/dynamic/crowdsec-plugin.yaml
```

**Verify:**
```bash
docker logs coolify-proxy --tail 50 | grep -i crowdsec
```

---

## Step 5 — Load the CrowdSec plugin in Traefik static config

**File:** `traefik-plugin-patch.yaml`

> ⚠️ MANUAL STEP — open the Coolify UI:
> **Servers → your server → Proxy → Dynamic Configuration**
> Paste the contents of `traefik-plugin-patch.yaml` into the static config editor and save.
> Coolify will restart Traefik automatically.

**Verify:**
```bash
docker logs coolify-proxy --tail 50 | grep -i plugin
# Should see: "loaded plugin: bouncer"
```

---

## Step 6 — Apply the crowdsec-bouncer middleware to your app in Coolify

> ⚠️ MANUAL STEP — in Coolify UI:
> Open your Node.js app → **Advanced → Custom Labels** and add:
> ```
> traefik.http.routers.<your-router-name>.middlewares=crowdsec-bouncer@file
> ```
> Replace `<your-router-name>` with the actual Traefik router name for your app.

**Verify:**
```bash
curl -I https://your-app-domain.com
```

---

## Step 7 — Start the Wazuh manager on your VPS

**File:** `install-wazuh-manager-docker.sh`
*Run this on your dedicated Wazuh VPS (or the same host if resources allow).*

```bash
bash install-wazuh-manager-docker.sh
```

**Verify:**
```bash
docker compose -C ~/wazuh-docker/single-node ps
# All services should be "Up (healthy)"
# Access dashboard: https://YOUR_WAZUH_MANAGER_IP
# Default login: admin / SecretPassword  <- change this immediately!
```

---

## Step 8 — Install Wazuh agent on the Coolify host

**File:** `install-wazuh-agent.sh`

```bash
export WAZUH_MANAGER=YOUR_WAZUH_MANAGER_IP
sudo -E bash install-wazuh-agent.sh
```

**Verify:**
```bash
sudo systemctl status wazuh-agent
# On the Wazuh dashboard: Agents -> should show this host as "Active"
```

---

## Step 9 — Add Docker + syscheck monitoring to the Wazuh agent

**File:** `wazuh-ossec-additions.xml`

```bash
sudo bash -c "cat wazuh-ossec-additions.xml >> /var/ossec/etc/ossec.conf"
sudo systemctl restart wazuh-agent
```

**Verify:**
```bash
sudo tail -50 /var/ossec/logs/ossec.log
# Look for: "Starting docker-listener" and syscheck initialisation lines
```

---

## Step 10 — Configure the CrowdSec -> Wazuh alert bridge

**File:** `crowdsec-wazuh-bridge.sh`

```bash
sudo bash crowdsec-wazuh-bridge.sh
```

**Verify:**
```bash
sudo cscli notifications list
sudo cscli notifications test wazuh_http_notifier
# Wazuh dashboard -> Security Events -> look for CrowdSec events
```

---

## Final Smoke Test

```bash
# 1. Trigger a test ban:
sudo cscli decisions add --ip 1.2.3.4 --reason "test" --duration 1m

# 2. Confirm firewall bouncer picked it up:
sudo iptables -L -n | grep 1.2.3.4

# 3. Remove the test ban:
sudo cscli decisions delete --ip 1.2.3.4

# 4. Confirm Wazuh received CrowdSec events via the dashboard.
```

---

*All done! Your Coolify server is now protected by CrowdSec (HTTP + SSH firewall) and monitored by Wazuh (container logs, file integrity, CVE detection).*
