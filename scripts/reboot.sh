#!/usr/bin/env bash

# Colors
REDU='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}--- Remote Reboot Initialized ---${NC}"

# 1. Check if a reboot is actually required (Debian/Ubuntu specific)
if [ -f /var/run/reboot-required ]; then
    echo -e "${REDU}[!] System reports a reboot IS required (updates pending).${NC}"
else
    echo -e "[i] System does not technically require a reboot, but proceeding as requested."
fi

# 2. Show current uptime
echo -e "[i] Current Uptime: $(uptime -p)"

# 3. Trigger the reboot
echo -e "${REDU}[!] REBOOTING SYSTEM NOW...${NC}"
echo -e "The SSH connection will now drop."

# We use 'nohup' and a slight delay so the SSH process has time
# to send the "Goodbye" message before the system kills the network.
sudo nohup bash -c "sleep 2 && reboot" > /dev/null 2>&1 &

exit 0
