#!/usr/bin/env bash
# ==============================================================================
# Script Name: log_cleanup.sh
# Description: Automated log cleanup, compression, and journal vacuuming
#              Prevents disk saturation on Ubuntu and CentOS/RHEL servers.
# Usage:
#   ./log_cleanup.sh [--days <retention_days>] [--target <log_dir>] [--dry-run]
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
    log_error "This script requires root/sudo privileges to clean system logs."
    exit 1
fi

# Default settings
RETENTION_DAYS=14
TARGET_DIR="/var/log"
DRY_RUN="false"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift 1
            ;;
        --help|-h)
            echo "Usage: $0 [--days <retention_days>] [--target <directory>] [--dry-run]"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

log_info "=========================================="
log_info "        AUTOMATED LOG CLEANUP TOOL        "
log_info "=========================================="
log_info "Target Directory: ${TARGET_DIR}"
log_info "Retention Period: Older than ${RETENTION_DAYS} days"
log_info "Dry Run Mode:     ${DRY_RUN}"

SPACE_BEFORE=$(df -h "$TARGET_DIR" | awk 'NR==2 {print $4}')
log_info "Available disk space before cleanup: ${SPACE_BEFORE}"

# 1. Compress uncompressed historical log files older than 2 days
log_info "Step 1: Compressing uncompressed rotated logs older than 2 days..."
if [[ "$DRY_RUN" == "true" ]]; then
    find "$TARGET_DIR" -type f \( -name "*.log.[0-9]*" -o -name "*-[0-9]*" \) ! -name "*.gz" ! -name "*.bz2" -mtime +2 -print
else
    find "$TARGET_DIR" -type f \( -name "*.log.[0-9]*" -o -name "*-[0-9]*" \) ! -name "*.gz" ! -name "*.bz2" -mtime +2 -exec gzip -9 {} + 2>/dev/null || true
fi

# 2. Delete compressed log archives older than retention period
log_info "Step 2: Purging archived logs older than ${RETENTION_DAYS} days..."
if [[ "$DRY_RUN" == "true" ]]; then
    find "$TARGET_DIR" -type f \( -name "*.gz" -o -name "*.old" -o -name "*.1" -o -name "*.xz" \) -mtime +"${RETENTION_DAYS}" -print
else
    DELETED_COUNT=0
    while IFS= read -r file; do
        rm -f "$file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    done < <(find "$TARGET_DIR" -type f \( -name "*.gz" -o -name "*.old" -o -name "*.1" -o -name "*.xz" \) -mtime +"${RETENTION_DAYS}")
    log_info "Removed ${DELETED_COUNT} obsolete log archive(s)."
fi

# 3. Clean Systemd Journal (Ubuntu & CentOS/RHEL)
if command -v journalctl &>/dev/null; then
    log_info "Step 3: Vacuuming systemd journal logs to retain ${RETENTION_DAYS} days..."
    if [[ "$DRY_RUN" == "false" ]]; then
        journalctl --vacuum-time="${RETENTION_DAYS}d" || true
    else
        log_info "[DRY-RUN] Would run: journalctl --vacuum-time=${RETENTION_DAYS}d"
    fi
fi

# 4. Truncate very large active .log files (> 100MB) safely if needed
log_info "Step 4: Inspecting active log files larger than 100MB..."
find "$TARGET_DIR" -maxdepth 2 -type f -name "*.log" -size +100M -exec ls -lh {} + 2>/dev/null || true

SPACE_AFTER=$(df -h "$TARGET_DIR" | awk 'NR==2 {print $4}')
log_success "Log cleanup process complete!"
log_info "Available disk space: Before: ${SPACE_BEFORE} | After: ${SPACE_AFTER}"
