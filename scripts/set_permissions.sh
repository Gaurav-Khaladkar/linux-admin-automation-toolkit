#!/usr/bin/env bash
# ==============================================================================
# Script Name: set_permissions.sh
# Description: Security auditing and permission enforcement toolkit.
#              Audits system files, standardizes directory/file permissions,
#              and scans for insecure SUID/SGID and world-writable files.
# Usage:
#   ./set_permissions.sh --harden-system
#   ./set_permissions.sh --fix-path <directory_path> [--user <owner>] [--group <grp>]
#   ./set_permissions.sh --audit
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be executed with root/sudo privileges."
    exit 1
fi

# 1. Harden Core Linux System Files
harden_system_files() {
    log_info "Hardening permissions on critical system configuration files..."

    # /etc/passwd: 644 root:root
    if [[ -f /etc/passwd ]]; then
        chown root:root /etc/passwd
        chmod 644 /etc/passwd
        log_success "/etc/passwd hardened (644 root:root)"
    fi

    # /etc/shadow: 640 or 000 root:shadow or root:root
    if [[ -f /etc/shadow ]]; then
        chown root:shadow /etc/shadow 2>/dev/null || chown root:root /etc/shadow
        chmod 640 /etc/shadow 2>/dev/null || chmod 000 /etc/shadow
        log_success "/etc/shadow hardened (640 root:shadow)"
    fi

    # /etc/group: 644 root:root
    if [[ -f /etc/group ]]; then
        chown root:root /etc/group
        chmod 644 /etc/group
        log_success "/etc/group hardened (644 root:root)"
    fi

    # /etc/gshadow: 640 root:shadow or root:root
    if [[ -f /etc/gshadow ]]; then
        chown root:shadow /etc/gshadow 2>/dev/null || chown root:root /etc/gshadow
        chmod 640 /etc/gshadow 2>/dev/null || chmod 000 /etc/gshadow
        log_success "/etc/gshadow hardened (640 root:shadow)"
    fi

    # /etc/sudoers: 440 root:root
    if [[ -f /etc/sudoers ]]; then
        chown root:root /etc/sudoers
        chmod 440 /etc/sudoers
        log_success "/etc/sudoers hardened (440 root:root)"
    fi

    # Restrict permissions on /home directories
    log_info "Securing user home directories..."
    for home_dir in /home/*; do
        if [[ -d "$home_dir" && "$home_dir" != "/home/lost+found" ]]; then
            chmod 700 "$home_dir"
            log_info "Hardened $home_dir to 700"
        fi
    done

    log_success "System security hardening completed."
}

# 2. Standardize Permissions on Application or Web Directory
fix_path_permissions() {
    local target_dir="$1"
    local owner="${2:-}"
    local group="${3:-}"

    if [[ ! -d "$target_dir" ]]; then
        log_error "Target directory does not exist: $target_dir"
        exit 1
    fi

    log_info "Standardizing permissions on directory: ${target_dir}"

    if [[ -n "$owner" && -n "$group" ]]; then
        log_info "Changing ownership to ${owner}:${group}..."
        chown -R "${owner}:${group}" "$target_dir"
    elif [[ -n "$owner" ]]; then
        log_info "Changing owner to ${owner}..."
        chown -R "${owner}" "$target_dir"
    fi

    # Standardize Directories to 755
    log_info "Setting directory permissions to 755 (rwxr-xr-x)..."
    find "$target_dir" -type d -exec chmod 755 {} +

    # Standardize Files to 644
    log_info "Setting file permissions to 644 (rw-r--r--)..."
    find "$target_dir" -type f -exec chmod 644 {} +

    log_success "Permissions standardized for ${target_dir}."
}

# 3. Security Audit: World-Writable and SUID Binaries
audit_permissions() {
    log_info "=========================================="
    log_info "        SECURITY PERMISSIONS AUDIT        "
    log_info "=========================================="

    log_info "Scanning for world-writable files across system..."
    local world_writable
    world_writable=$(find / -xdev -type f -perm -0002 ! -path "/proc/*" ! -path "/sys/*" 2>/dev/null | head -n 25 || true)
    if [[ -n "$world_writable" ]]; then
        log_warn "Discovered world-writable files (showing up to 25):"
        echo "$world_writable"
    else
        log_success "No unexpected world-writable files found."
    fi

    log_info "Scanning for SUID (SetUID) executables..."
    local suid_files
    suid_files=$(find / -xdev -type f -perm -4000 ! -path "/proc/*" 2>/dev/null | head -n 25 || true)
    if [[ -n "$suid_files" ]]; then
        log_info "Identified SUID binaries (showing up to 25):"
        echo "$suid_files"
    fi

    log_info "Auditing /etc/shadow permissions..."
    ls -la /etc/shadow /etc/passwd /etc/sudoers 2>/dev/null || true

    log_success "Audit completed."
}

# ------------------------------------------------------------------------------
# Entrypoint & CLI Parsing
# ------------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --harden-system                      Enforce strict permissions on core system files (/etc/shadow, /etc/sudoers, /home)
  --fix-path <dir> [--user <u>] [--group <g>] Enforce 755 (dirs) and 644 (files) on target path
  --audit                              Audit world-writable files, SUID binaries, and system file permissions
  --help                               Display this help guide
EOF
    exit 1
fi

case "$1" in
    --harden-system)
        harden_system_files
        ;;
    --fix-path)
        TARGET="$2"
        OWNER=""
        GRP=""
        shift 2
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --user)
                    OWNER="$2"
                    shift 2
                    ;;
                --group)
                    GRP="$2"
                    shift 2
                    ;;
                *)
                    break
                    ;;
            esac
        done
        fix_path_permissions "$TARGET" "$OWNER" "$GRP"
        ;;
    --audit)
        audit_permissions
        ;;
    *)
        log_error "Unknown option: $1"
        exit 1
        ;;
esac
