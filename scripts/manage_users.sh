#!/usr/bin/env bash
# ==============================================================================
# Script Name: manage_users.sh
# Description: Automated user and group provisioning, modification, and locking
#              Compatible with both Ubuntu (Debian) and CentOS/RHEL.
# Usage:
#   ./manage_users.sh --add-user <username> [--group <group>] [--sudo]
#   ./manage_users.sh --del-user <username> [--backup-home]
#   ./manage_users.sh --add-group <groupname>
#   ./manage_users.sh --lock-user <username>
#   ./manage_users.sh --unlock-user <username>
#   ./manage_users.sh --batch <users.csv>
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

# Root privilege check
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be executed as root or with sudo privileges."
    exit 1
fi

# Detect Operating System (Ubuntu vs CentOS/RHEL)
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                ADMIN_GROUP="sudo"
                OS_TYPE="debian"
                ;;
            centos|rhel|rocky|almalinux|fedora)
                ADMIN_GROUP="wheel"
                OS_TYPE="rhel"
                ;;
            *)
                ADMIN_GROUP="wheel"
                OS_TYPE="unknown"
                ;;
        esac
    else
        log_warn "Unable to detect OS from /etc/os-release. Defaulting admin group to 'wheel'."
        ADMIN_GROUP="wheel"
        OS_TYPE="unknown"
    fi
    log_info "Detected OS family: ${OS_TYPE} (Privileged Group: ${ADMIN_GROUP})"
}

# Create a new user
add_user() {
    local username="$1"
    local group="${2:-}"
    local is_sudo="${3:-false}"
    local default_shell="/bin/bash"

    if id "$username" &>/dev/null; then
        log_warn "User '${username}' already exists."
        return 0
    fi

    log_info "Creating user '${username}'..."
    useradd -m -s "$default_shell" "$username"

    # Set strict permissions on home directory
    chmod 700 "/home/${username}"

    # Generate secure random temporary password if not set
    local temp_pass
    temp_pass=$(openssl rand -base64 12)
    echo "${username}:${temp_pass}" | chpasswd
    # Force password change on first login
    chage -d 0 "$username" 2>/dev/null || true

    # Add to specific secondary group if provided
    if [[ -n "$group" ]]; then
        if ! getent group "$group" &>/dev/null; then
            log_info "Group '${group}' does not exist. Creating..."
            groupadd "$group"
        fi
        usermod -aG "$group" "$username"
        log_info "Added '${username}' to group '${group}'."
    fi

    # Add to sudo/wheel if requested
    if [[ "$is_sudo" == "true" ]]; then
        usermod -aG "$ADMIN_GROUP" "$username"
        log_info "Granted administrative (${ADMIN_GROUP}) access to '${username}'."
    fi

    log_success "User '${username}' created successfully."
    echo "--------------------------------------------------------"
    echo " Username:          ${username}"
    echo " Home Directory:    /home/${username}"
    echo " Temporary Password:${temp_pass}"
    echo " (Password change is enforced on first login)"
    echo "--------------------------------------------------------"
}

# Delete a user
del_user() {
    local username="$1"
    local backup_home="${2:-false}"

    if ! id "$username" &>/dev/null; then
        log_warn "User '${username}' does not exist."
        return 0
    fi

    if [[ "$backup_home" == "true" && -d "/home/${username}" ]]; then
        local backup_dir="/var/backups/deleted_users"
        mkdir -p "$backup_dir"
        local archive_name="${backup_dir}/${username}_home_$(date +%Y%m%d%H%M%S).tar.gz"
        log_info "Backing up home directory for '${username}' to ${archive_name}..."
        tar -czf "$archive_name" -C "/home" "$username"
        log_success "Home directory archived."
    fi

    log_info "Terminating any running processes for '${username}'..."
    pkill -u "$username" 2>/dev/null || true

    log_info "Removing user '${username}'..."
    userdel -r "$username" 2>/dev/null || userdel "$username"
    log_success "User '${username}' successfully removed."
}

# Create a group
add_group() {
    local groupname="$1"
    if getent group "$groupname" &>/dev/null; then
        log_warn "Group '${groupname}' already exists."
        return 0
    fi
    groupadd "$groupname"
    log_success "Group '${groupname}' created successfully."
}

# Lock user account
lock_user() {
    local username="$1"
    if ! id "$username" &>/dev/null; then
        log_error "User '${username}' does not exist."
        exit 1
    fi
    passwd -l "$username"
    log_success "User account '${username}' locked."
}

# Unlock user account
unlock_user() {
    local username="$1"
    if ! id "$username" &>/dev/null; then
        log_error "User '${username}' does not exist."
        exit 1
    fi
    passwd -u "$username"
    log_success "User account '${username}' unlocked."
}

# Batch process from CSV (Format: username,group,is_sudo)
batch_process() {
    local csv_file="$1"
    if [[ ! -f "$csv_file" ]]; then
        log_error "CSV file not found: $csv_file"
        exit 1
    fi

    log_info "Processing batch user file: ${csv_file}"
    while IFS=',' read -r username group is_sudo || [[ -n "$username" ]]; do
        # Skip empty lines or comments
        [[ -z "$username" || "$username" =~ ^# ]] && continue
        # Trim whitespace
        username=$(echo "$username" | xargs)
        group=$(echo "$group" | xargs)
        is_sudo=$(echo "$is_sudo" | xargs)

        log_info "Processing line: User=${username}, Group=${group}, Sudo=${is_sudo}"
        add_user "$username" "$group" "$is_sudo"
    done < "$csv_file"
    log_success "Batch user creation complete."
}

# Display Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --add-user <user> [--group <grp>] [--sudo]   Create a new user with home & password
  --del-user <user> [--backup-home]            Delete a user (optionally backup home dir)
  --add-group <group>                          Create a new system group
  --lock-user <user>                           Lock an existing user's login
  --unlock-user <user>                         Unlock a locked user account
  --batch <file.csv>                           Batch create users from CSV file
  --help                                       Display this help message

Examples:
  sudo $0 --add-user alice --group developers --sudo
  sudo $0 --del-user bob --backup-home
  sudo $0 --batch users_list.csv
EOF
}

# ------------------------------------------------------------------------------
# Entrypoint & CLI Parsing
# ------------------------------------------------------------------------------
detect_os

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --add-user)
            USER="$2"
            GROUP=""
            IS_SUDO="false"
            shift 2
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --group)
                        GROUP="$2"
                        shift 2
                        ;;
                    --sudo)
                        IS_SUDO="true"
                        shift 1
                        ;;
                    *)
                        break
                        ;;
                esac
            done
            add_user "$USER" "$GROUP" "$IS_SUDO"
            exit 0
            ;;
        --del-user)
            USER="$2"
            BACKUP="false"
            shift 2
            if [[ $# -gt 0 && "$1" == "--backup-home" ]]; then
                BACKUP="true"
                shift 1
            fi
            del_user "$USER" "$BACKUP"
            exit 0
            ;;
        --add-group)
            add_group "$2"
            shift 2
            exit 0
            ;;
        --lock-user)
            lock_user "$2"
            shift 2
            exit 0
            ;;
        --unlock-user)
            unlock_user "$2"
            shift 2
            exit 0
            ;;
        --batch)
            batch_process "$2"
            shift 2
            exit 0
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done
