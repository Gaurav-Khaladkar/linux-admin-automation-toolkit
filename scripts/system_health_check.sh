#!/usr/bin/env bash
# ==============================================================================
# Script Name: system_health_check.sh
# Description: Linux system health audit (CPU, Memory, Disk, Services)
#              Tested on Ubuntu and CentOS/RHEL.
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================================="
echo "               SYSTEM HEALTH REPORT                       "
echo " Date: $(date '+%Y-%m-%d %H:%M:%S') | Host: $(hostname)"
echo " OS:   $(grep -oP '(?<=PRETTY_NAME=")[^"]*' /etc/os-release 2>/dev/null || uname -s)"
echo "=========================================================="

# 1. Disk Space Check
echo -e "\n${BLUE}--- [Disk Utilization (Partitions >= 80%)] ---${NC}"
DISK_WARNING=$(df -hP | awk '0+$5 >= 80 {print $0}')
if [[ -n "$DISK_WARNING" ]]; then
    echo -e "${RED}[WARNING] High disk usage detected:${NC}"
    echo "$DISK_WARNING"
else
    echo -e "${GREEN}[OK] All filesystem partitions are below 80% usage.${NC}"
fi

# 2. Memory Utilization
echo -e "\n${BLUE}--- [Memory Usage] ---${NC}"
free -m | awk 'NR==2{printf "RAM: Used: %s MB / Total: %s MB (%.2f%%)\n", $3, $2, $3*100/$2 }'
free -m | awk 'NR==3{if ($2 > 0) printf "Swap: Used: %s MB / Total: %s MB (%.2f%%)\n", $3, $2, $3*100/$2; else print "Swap: Disabled" }'

# 3. CPU Load Average
echo -e "\n${BLUE}--- [System Load Average] ---${NC}"
UPTIME_OUTPUT=$(uptime)
echo "$UPTIME_OUTPUT"

# 4. Top 5 CPU Consuming Processes
echo -e "\n${BLUE}--- [Top 5 CPU Processes] ---${NC}"
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 6

# 5. Top 5 Memory Consuming Processes
echo -e "\n${BLUE}--- [Top 5 Memory Processes] ---${NC}"
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 6

# 6. Failed Systemd Services
echo -e "\n${BLUE}--- [Failed Systemd Services] ---${NC}"
FAILED_SERVICES=$(systemctl --failed --no-legend 2>/dev/null || true)
if [[ -n "$FAILED_SERVICES" ]]; then
    echo -e "${RED}[ALERT] Failed services found:${NC}"
    echo "$FAILED_SERVICES"
else
    echo -e "${GREEN}[OK] No failed system services found.${NC}"
fi

echo "=========================================================="
