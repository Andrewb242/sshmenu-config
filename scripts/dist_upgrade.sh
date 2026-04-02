#!/usr/bin/env bash

# ==============================================================================
# OS DISTRIBUTION & KERNEL UPGRADE SCRIPT
# Purpose: Deep upgrade of packages, kernel, and dependencies to resolve CVEs.
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}--- DISTRIBUTION UPGRADE STARTING ---${NC}"

# 1. LOCK CHECK (Prevents script from failing if another update is running)
echo -e "${BLUE}[1/5] Checking for package manager locks...${NC}"
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
    echo -e "${YELLOW}Waiting for other package manager processes to finish...${NC}"
    sleep 5
done

# 2. SOURCE UPDATE
echo -e "${BLUE}[2/5] Refreshing package repositories...${NC}"
sudo apt-get update -y

# 3. STANDARD UPGRADE
echo -e "${BLUE}[3/5] Performing standard package upgrade...${NC}"
sudo apt-get upgrade -y

# 4. DISTRIBUTION UPGRADE (Full Upgrade)
# This is the step that actually installs the new Kernel to fix your CVEs
echo -e "${BLUE}[4/5] Performing FULL distribution upgrade (dist-upgrade)...${NC}"
echo -e "${YELLOW}Note: This handles changing dependencies and new kernel versions.${NC}"
sudo apt-get dist-upgrade -y

# 5. POST-UPGRADE CLEANUP
echo -e "${BLUE}[5/5] Cleaning up obsolete packages...${NC}"
sudo apt-get autoremove -y
sudo apt-get autoclean

echo -e "${CYAN}------------------------------------------------${NC}"

# FINAL REBOOT CHECK
if [ -f /var/run/reboot-required ]; then
    echo -e "${RED}CRITICAL: A reboot is REQUIRED to apply the new Kernel.${NC}"
    echo -e "${YELLOW}Please remember to reboot manually soon.${NC}"
else
    echo -e "${GREEN}✅ Upgrade complete. No reboot required.${NC}"
fi

echo -e "${CYAN}--- PROCESS FINISHED ---${NC}"
