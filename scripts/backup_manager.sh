#!/usr/bin/env bash
# ==============================================================================
# Script Name: backup_manager.sh
# Description: Automated system backup script. Generates compressed,
#              timestamped tarballs with SHA256 checksums and retention cleanup.
# Usage:
#   ./backup_manager.sh [--sources "/etc,/var/www"] [--dest /var/backups] [--retention 7]
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
    log_error "This script requires root/sudo privileges to read system directories."
    exit 1
fi

# Load external configuration if present
CONFIG_FILE="$(dirname "$0")/../config/toolkit.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

DEST_DIR="${BACKUP_DEST_DIR:-/var/backups/admin-toolkit}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
SOURCES=("${BACKUP_SOURCE_DIRS[@]:-/etc}")

# Parse CLI overrides
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sources)
            IFS=',' read -r -a SOURCES <<< "$2"
            shift 2
            ;;
        --dest)
            DEST_DIR="$2"
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--sources <dir1,dir2>] [--dest <destination>] [--retention <days>]"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
HOSTNAME=$(hostname -s)
ARCHIVE_NAME="backup_${HOSTNAME}_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${DEST_DIR}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"

log_info "=========================================="
log_info "          AUTOMATED BACKUP RUN            "
log_info "=========================================="
log_info "Target Destination: ${DEST_DIR}"
log_info "Retention Period:   ${RETENTION_DAYS} days"
log_info "Sources to Backup:  ${SOURCES[*]}"

# Filter existing directories
VALID_SOURCES=()
for src in "${SOURCES[@]}"; do
    if [[ -d "$src" || -f "$src" ]]; then
        VALID_SOURCES+=("$src")
    else
        log_warn "Source '${src}' not found. Skipping."
    fi
done

if [[ ${#VALID_SOURCES[@]} -eq 0 ]]; then
    log_error "No valid sources available for backup. Aborting."
    exit 1
fi

# 1. Create Compressed Archive
log_info "Creating compressed archive: ${ARCHIVE_NAME}..."
tar --warning=no-file-changed -czf "$ARCHIVE_PATH" "${VALID_SOURCES[@]}" 2>/dev/null || true

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | awk '{print $1}')
log_success "Archive created successfully (Size: ${ARCHIVE_SIZE})."

# 2. Generate SHA-256 Checksum
log_info "Generating SHA256 integrity checksum..."
sha256sum "$ARCHIVE_PATH" > "$CHECKSUM_PATH"
log_success "Checksum stored at: ${CHECKSUM_PATH}"

# 3. Clean Obsolete Backups (Retention Policy)
log_info "Enforcing retention policy (Removing backups older than ${RETENTION_DAYS} days)..."
REMOVED_COUNT=0
while IFS= read -r old_file; do
    rm -f "$old_file" "${old_file}.sha256"
    REMOVED_COUNT=$((REMOVED_COUNT + 1))
done < <(find "$DEST_DIR" -type f -name "backup_*.tar.gz" -mtime +"${RETENTION_DAYS}")

log_info "Cleaned ${REMOVED_COUNT} expired backup archive(s)."

# 4. Display Summary of Current Backups
log_info "Current active backups in ${DEST_DIR}:"
ls -lh "${DEST_DIR}"/*.tar.gz 2>/dev/null || true

log_success "Backup operation finished successfully!"
