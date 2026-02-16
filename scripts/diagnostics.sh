#!/usr/bin/env bash

# ============================
# SSH Diagnostics Script
# ============================

USER="root"
IP=""

usage() {
    echo -e "Usage: $0 -i <ip_address> [-u <user>]"
    exit 1
}

while getopts "i:u:" opt; do
  case $opt in
    i) IP="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    *) usage ;;
  esac
done

if [[ -z "$IP" ]]; then
    echo -e "\033[31mError: IP address (-i) is required.\033[0m"
    usage
fi

echo -e "\033[1;34m🔍 Gathering Diagnostics for ${USER}@${IP}...\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"

ssh -T "${USER}@${IP}" << 'EOF'
    echo -e "\n\033[1;33m--- System Usage ---\033[0m"
    uptime
    echo ""
    free -h
    echo ""
    df -h | grep '^/dev/'

    echo -e "\n\033[1;33m--- Firewall Configuration ---\033[0m"
    if command -v ufw >/dev/null 2>&1; then
        # Check UFW (Ubuntu/Debian)
        STATUS=$(ufw status | head -n 1)
        if [[ "$STATUS" == "Status: active" ]]; then
            ufw status numbered
        else
            echo -e "\033[31mUFW is installed but INACTIVE.\033[0m"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # Check Firewalld (CentOS/RHEL/Fedora)
        echo "Firewalld Zones & Rules:"
        firewall-cmd --list-all
    else
        echo -e "\033[31mNo standard firewall (UFW/Firewalld) detected.\033[0m"
        echo "Checking raw iptables summary:"
        iptables -L -n | head -n 5
    fi

    echo -e "\n\033[1;33m--- Top 5 CPU Processes ---\033[0m"
    ps -eo pcpu,pmem,user,args --sort=-pcpu | head -n 6

    if command -v docker >/dev/null 2>&1; then
        echo -e "\n\033[1;33m--- Docker Containers (Running) ---\033[0m"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    fi

    echo -e "\n\033[1;33m--- Network Listening Ports ---\033[0m"
    ss -tunlp | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -nu | xargs echo "Open Ports:"
EOF

echo -e "\033[1;36m------------------------------------------------\033[0m"
echo -e "\033[1;32m✅ Diagnostics Complete. Press Enter to return to menu.\033[0m"
read
