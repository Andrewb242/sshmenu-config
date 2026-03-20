#!/usr/bin/env bash

# ==============================================================================
# SYSTEM MAINTENANCE & HEALTH SCRIPT
# Designed to be executed locally or via 'ssh -t user@ip "bash -s" < script.sh'
# ==============================================================================

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🚀 STARTING SYSTEM MAINTENANCE SUITE${NC}"
echo -e "${CYAN}------------------------------------------------${NC}"

# --- 1. PRE-FLIGHT CHECKS ---
echo -e "${BLUE}[1/7] System Overview & Resource Check${NC}"
echo -e "Hostname: $(hostname)"
echo -e "Uptime:   $(uptime -p)"

# Check Disk Usage
echo -e "\n${YELLOW}Disk Usage:${NC}"
df -h | grep -E '^/dev/' | awk '{ printf "  %-15s %-5s used (%s)\n", $1, $5, $6 }'

# Check Memory Usage
echo -e "\n${YELLOW}Memory Usage:${NC}"
free -h | awk '/^Mem:/ {print "  RAM:  "$3"/"$2} /^Swap:/ {print "  Swap: "$3"/"$4}'

# --- 2. SERVICE HEALTH CHECK ---
echo -e "\n${BLUE}[2/7] Checking for Failed Services...${NC}"
FAILED_SERVICES=$(systemctl list-units --state=failed --no-legend)
if [ -n "$FAILED_SERVICES" ]; then
    echo -e "${RED}⚠️ Found failed services:${NC}"
    echo "$FAILED_SERVICES"
else
    echo -e "${GREEN}✅ All system services are running correctly.${NC}"
fi

# --- 3. SECURITY & UPDATES ---
echo -e "\n${BLUE}[3/7] APT Maintenance & Security Updates${NC}"
echo -e "${YELLOW}[!] Holding Docker packages to prevent container restarts...${NC}"
sudo apt-mark hold docker.io docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

sudo apt-get update -qq
echo -e "Performing distribution upgrade and removing stale packages..."
sudo apt-get dist-upgrade -y -qq
sudo apt-get autoremove --purge -y -qq
sudo apt-get autoclean -qq
sudo apt-get clean

# --- 4. DOCKER HYGIENE ---
if command -v docker >/dev/null 2>&1; then
    echo -e "\n${BLUE}[4/7] Docker Optimization${NC}"
    # Count dangling images/stopped containers
    STOPPED=$(docker ps -a -q -f status=exited | wc -l)
    DANGLING=$(docker images -f "dangling=true" -q | wc -l)

    echo -e "Found $STOPPED stopped containers and $DANGLING dangling images."
    if [ "$STOPPED" -gt 0 ] || [ "$DANGLING" -gt 0 ]; then
        echo -ne "${YELLOW}[?] Prune Docker system? (y/n): ${NC}"
        read -r prune_docker </dev/tty
        if [[ "$prune_docker" == "y" || "$prune_docker" == "Y" ]]; then
            docker system prune -f
            echo -e "${GREEN}Docker cleaned.${NC}"
        fi
    fi
else
    echo -e "\n${BLUE}[4/7] Docker not installed, skipping...${NC}"
fi

# --- 5. LOG & JOURNAL MANAGEMENT ---
echo -e "\n${BLUE}[5/7] Vacuuming Logs & Journals${NC}"
CURRENT_JOURNAL=$(du -sh /var/log/journal 2>/dev/null | cut -f1)
echo -e "Current Journal Size: $CURRENT_JOURNAL"
sudo journalctl --vacuum-time=7d

# Find massive logs (>100MB)
LARGE_LOGS=$(sudo find /var/log -type f -size +100M)
if [ -n "$LARGE_LOGS" ]; then
    echo -e "${YELLOW}Detected massive log files (>100MB):${NC}"
    echo "$LARGE_LOGS"
    echo -ne "${YELLOW}[?] Truncate (empty) these logs? (y/n): ${NC}"
    read -r trunc_res </dev/tty
    if [[ "$trunc_res" == "y" || "$trunc_res" == "Y" ]]; then
        for log in $LARGE_LOGS; do
            sudo truncate -s 0 "$log"
            echo "Truncated: $log"
        done
    fi
fi

# --- 6. SECURITY AUDIT ---
echo -e "\n${BLUE}[6/7] Quick Security Check${NC}"
LAST_LOGINS=$(last -n 5 -a)
echo -e "${YELLOW}Recent Logins:${NC}\n$LAST_LOGINS"

FAILED_LOGINS=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 5)
if [ -n "$FAILED_LOGINS" ]; then
    echo -e "${RED}Recent Failed Login Attempts:${NC}"
    echo "$FAILED_LOGINS"
fi

# --- 7. REBOOT CHECK ---
echo -e "\n${BLUE}[7/7] Finalizing...${NC}"
if [ -f /var/run/reboot-required ]; then
    echo -e "${RED}⚠️  SYSTEM REBOOT REQUIRED (Kernel or library updates applied)${NC}"
else
    echo -e "${GREEN}✅ No reboot required.${NC}"
fi

echo -e "\n${CYAN}------------------------------------------------${NC}"
echo -e "${GREEN}✨ Maintenance cycle finished for $(hostname)!${NC}"
echo -e "${CYAN}------------------------------------------------${NC}"
