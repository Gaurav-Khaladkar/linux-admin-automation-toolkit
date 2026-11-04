#!/usr/bin/env bash
# ==============================================================================
# Script Name: install_cron.sh
# Description: Installs and registers toolkit cron jobs for automated execution.
#              Compatible with both Ubuntu (cron) and CentOS (crond).
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be executed as root or with sudo."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_TARGET="/opt/linux-toolkit"

log_info "Deploying toolkit scripts to ${INSTALL_TARGET}..."
mkdir -p "${INSTALL_TARGET}"
cp -r "${TOOLKIT_ROOT}/scripts" "${INSTALL_TARGET}/"
cp -r "${TOOLKIT_ROOT}/config" "${INSTALL_TARGET}/"
chmod +x "${INSTALL_TARGET}/scripts/"*.sh

# Install cron configuration into /etc/cron.d/
CRON_TARGET="/etc/cron.d/linux-admin-toolkit"
log_info "Configuring scheduled cron jobs in ${CRON_TARGET}..."

cat <<EOF > "${CRON_TARGET}"
# /etc/cron.d/linux-admin-toolkit
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin

# 1. Weekly Log Cleanup (Every Sunday at 02:00 AM)
0 2 * * 0 root ${INSTALL_TARGET}/scripts/log_cleanup.sh --days 14 >> /var/log/admin-toolkit-cleanup.log 2>&1

# 2. Daily System Backup (Every day at 03:00 AM)
0 3 * * * root ${INSTALL_TARGET}/scripts/backup_manager.sh >> /var/log/admin-toolkit-backup.log 2>&1

# 3. Weekly Permissions Audit (Every Monday at 04:00 AM)
0 4 * * 1 root ${INSTALL_TARGET}/scripts/set_permissions.sh --audit >> /var/log/admin-toolkit-audit.log 2>&1
EOF

chmod 644 "${CRON_TARGET}"

# Ensure cron service is active (cron on Ubuntu/Debian, crond on CentOS/RHEL)
if systemctl is-active --quiet cron; then
    log_success "Cron service is active (Ubuntu/Debian)."
elif systemctl is-active --quiet crond; then
    log_success "Crond service is active (CentOS/RHEL)."
else
    log_info "Enabling and starting cron service..."
    systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null || true
    systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null || true
fi

log_success "Automated cron schedule registered successfully!"
