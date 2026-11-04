#!/usr/bin/env bash
# ==============================================================================
# Script Name: test_syntax.sh
# Description: Validates Bash syntax across all scripts in the toolkit.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Running Bash Syntax Validation ==="
FAILED=0

for script in "${TOOLKIT_ROOT}/scripts/"*.sh "${TOOLKIT_ROOT}/cron/"*.sh; do
    if [[ -f "$script" ]]; then
        echo -n "Checking $(basename "$script")... "
        if bash -n "$script"; then
            echo "[OK]"
        else
            echo "[FAILED]"
            FAILED=1
        fi
    fi
done

if [[ $FAILED -eq 0 ]]; then
    echo "All scripts passed syntax validation!"
    exit 0
else
    echo "One or more scripts failed syntax validation."
    exit 1
fi
