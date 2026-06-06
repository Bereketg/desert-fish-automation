#!/usr/bin/env bash
# =============================================================================
# Desert Fish — VM2 Bootstrap Script
# Run this ONCE on a fresh Oracle Cloud ARM Ubuntu 22.04 instance.
#
# What this script does (in order):
#   1. Updates the OS and installs prerequisites
#   2. Installs Docker Engine + Docker Compose plugin
#   3. Hardens the firewall (UFW) — only required ports open
#   4. Clones your Git repository (update REPO_URL below)
#   5. Generates secrets and writes .env
#   6. Starts the NetBox + Oxidized stack
#   7. Waits for NetBox to be healthy, then prints next steps
#
# Usage:
#   chmod +x vm2_install.sh
#   sudo ./vm2_install.sh
# =============================================================================

set -euo pipefail

# ── Configuration — EDIT THESE BEFORE RUNNING ────────────────────────────────
REPO_URL="https://github.com/YOUR_ORG/desert-fish-automation.git"   # CHANGE ME
REPO_BRANCH="main"
DEPLOY_DIR="/opt/desert-fish"
VM2_SUBDIRECTORY="Automation/vm2-setup"   # path within the repo

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${GREEN}════════════════════════════════════════${NC}"; \
            echo -e "${GREEN} $*${NC}"; \
            echo -e "${GREEN}════════════════════════════════════════${NC}"; }

# ── Must run as root ───────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { echo -e "${RED}Run as root: sudo $0${NC}"; exit 1; }

# ═════════════════════════════════════════════════════════════════════════════
section "Step 1 — OS update and prerequisites"
# ═════════════════════════════════════════════════════════════════════════════
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  curl git ufw python3 python3-pip ca-certificates gnupg lsb-release

# ═════════════════════════════════════════════════════════════════════════════
section "Step 2 — Install Docker Engine"
# WHY: NetBox and Oxidized are distributed as Docker images. Docker Compose
#      lets us define the entire stack in one YAML file and start/stop it
#      with a single command.
# ═════════════════════════════════════════════════════════════════════════════
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
                          docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  info "Docker installed: $(docker --version)"
else
  info "Docker already installed: $(docker --version)"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "Step 3 — Firewall (UFW)"
# WHY: Oracle Cloud VMs are internet-facing. We only open the ports we need:
#   22   → SSH (management)
#   8000 → NetBox web UI (restrict to your management IP in production)
#   8888 → Oxidized web UI (restrict to management IP in production)
# Everything else is blocked by default.
# ═════════════════════════════════════════════════════════════════════════════
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment "SSH"
ufw allow 8000/tcp comment "NetBox UI"
ufw allow 8888/tcp comment "Oxidized UI"
ufw --force enable
info "Firewall configured"
ufw status

# ═════════════════════════════════════════════════════════════════════════════
section "Step 4 — Clone repository"
# ═════════════════════════════════════════════════════════════════════════════
if [[ -d "$DEPLOY_DIR" ]]; then
  warn "$DEPLOY_DIR already exists — pulling latest changes"
  git -C "$DEPLOY_DIR" pull
else
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$DEPLOY_DIR"
fi

STACK_DIR="$DEPLOY_DIR/$VM2_SUBDIRECTORY"
cd "$STACK_DIR"
info "Working directory: $STACK_DIR"

# ═════════════════════════════════════════════════════════════════════════════
section "Step 5 — Generate secrets (.env)"
# WHY: We auto-generate cryptographically random secrets so no two
#      installations share the same keys or passwords.
# ═════════════════════════════════════════════════════════════════════════════
if [[ -f .env ]]; then
  warn ".env already exists — skipping secret generation (delete it to regenerate)"
else
  info "Generating secrets..."
  PG_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
  REDIS_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
  REDIS_CACHE_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
  SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
  ADMIN_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(20))")
  API_TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(20))")

  cat > .env <<EOF
# Auto-generated by vm2_install.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# DO NOT COMMIT THIS FILE TO GIT

POSTGRES_PASSWORD=${PG_PASS}
REDIS_PASSWORD=${REDIS_PASS}
REDIS_CACHE_PASSWORD=${REDIS_CACHE_PASS}
NETBOX_SECRET_KEY=${SECRET_KEY}
NETBOX_SUPERUSER_PASSWORD=${ADMIN_PASS}
NETBOX_API_TOKEN=${API_TOKEN}
EOF

  chmod 600 .env
  info ".env written (chmod 600)"
  echo ""
  echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}║  SAVE THESE CREDENTIALS — they will not be shown again   ║${NC}"
  echo -e "${YELLOW}╠══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${YELLOW}║  NetBox URL      : http://$(hostname -I | awk '{print $1}'):8000  ${NC}"
  echo -e "${YELLOW}║  NetBox Username : admin                                  ║${NC}"
  echo -e "${YELLOW}║  NetBox Password : ${ADMIN_PASS}  ${NC}"
  echo -e "${YELLOW}║  NetBox API Token: ${API_TOKEN}  ${NC}"
  echo -e "${YELLOW}║  Oxidized URL    : http://$(hostname -I | awk '{print $1}'):8888  ${NC}"
  echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  warn "Copy NETBOX_API_TOKEN into:"
  warn "  1. Automation/vm2-setup/oxidized/config  → token: field"
  warn "  2. Automation/group_vars/all/vault.yml   → vault_netbox_token: field"
fi

# ═════════════════════════════════════════════════════════════════════════════
section "Step 6 — Start the stack"
# ═════════════════════════════════════════════════════════════════════════════
docker compose pull --quiet
docker compose up -d
info "Stack started"

# ═════════════════════════════════════════════════════════════════════════════
section "Step 7 — Wait for NetBox to become healthy"
# ═════════════════════════════════════════════════════════════════════════════
info "NetBox takes ~90 seconds on first start (database migrations running)..."
MAX_WAIT=180
ELAPSED=0
until curl -sf "http://localhost:8000/api/" >/dev/null 2>&1; do
  sleep 5; ELAPSED=$((ELAPSED+5))
  echo -n "."
  [[ $ELAPSED -ge $MAX_WAIT ]] && { echo ""; warn "Timeout — check: docker compose logs netbox"; break; }
done
echo ""
info "NetBox is up!"

# ═════════════════════════════════════════════════════════════════════════════
section "Next Steps"
# ═════════════════════════════════════════════════════════════════════════════
VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "  1. Open NetBox:   http://${VM_IP}:8000"
echo "     Login:         admin / <password from step 5 above>"
echo ""
echo "  2. Copy NETBOX_API_TOKEN from .env into oxidized/config and vault.yml"
echo ""
echo "  3. Run the populate playbook from your Ansible control node:"
echo "     ansible-playbook Automation/playbooks/netbox_populate.yml"
echo ""
echo "  4. Restart Oxidized to pick up the new NetBox source:"
echo "     docker compose restart oxidized"
echo ""
echo "  5. Open Oxidized: http://${VM_IP}:8888"
echo "     You should see all 60 switches being polled within 60 seconds."
echo ""
info "VM2 setup complete!"
