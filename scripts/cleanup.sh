#!/usr/bin/env bash

# ==========================================
# SSH Remote Maintenance & Cleanup Script
# ==========================================

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

clear
echo -e "\033[1;35m🧹 REMOTE CLEANUP SYSTEM for ${USER}@${IP}\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"

# Selection of tasks
echo -e "This script will perform the following:"
echo -e " 1. Remove unused APT packages and purge old configs."
echo -e " 2. Clean the APT package cache to reclaim disk space."
echo -e " 3. Prune Docker (stopped containers, dangling images, unused networks)."
echo -e " 4. Vacuum Systemd journals (logs) older than 7 days."
echo ""

ask_confirm() {
    echo -ne "\033[1m[?] Proceed with cleanup? (y/n): \033[0m"
    read -r choice
    case "$choice" in
        y|Y ) return 0;;
        * ) echo -e "\033[31mCleanup aborted.\033[0m"; exit 1;;
    esac
}

ask_confirm

echo -e "\n\033[1;32m✅ Connecting to server...\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"

#!/usr/bin/env bash

# ... (keep the same header/getopts/checklist from before) ...

ssh -T "${USER}@${IP}" bash -s << 'EOF'
    echo -e "\033[1;33m[!] Holding Docker packages to prevent container restarts...\033[0m"
    sudo apt-mark hold docker.io docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

    # 1. APT Cleanup & Phased Updates
    echo -e "\033[1;34m[1/5] Cleaning up APT & checking held packages...\033[0m"
    # 'dist-upgrade' or 'full-upgrade' helps with those "7 not upgraded" items
    sudo apt-get dist-upgrade -y
    sudo apt-get autoremove --purge -y
    sudo apt-get autoclean

    # 2. Reclaim Space from /var/cache/apt
    echo -e "\033[1;34m[2/5] Clearing local package archive...\033[0m"
    sudo apt-get clean

    # 3. Docker Cleanup
    if command -v docker >/dev/null 2>&1; then
        echo -e "\033[1;34m[3/5] Pruning Docker system...\033[0m"
        docker system prune -f
    fi

    # 4. Journal Vacuuming
    echo -e "\033[1;34m[4/5] Vacuuming systemd journals...\033[0m"
    sudo journalctl --vacuum-time=7d

    # 5. LARGE LOG FILE FINDER
    echo -e "\033[1;34m[5/5] Checking for massive log files in /var/log...\033[0m"
    # Finds files over 100MB
    LARGE_LOGS=$(sudo find /var/log -type f -size +100M)

    if [ -n "$LARGE_LOGS" ]; then
        echo -e "\033[1;33mFound logs > 100MB:\033[0m"
        echo "$LARGE_LOGS"
        echo -n "Would you like to truncate (empty) these files? (y/n): "
        read -r trunc_res
        if [[ "$trunc_res" == "y" || "$trunc_res" == "Y" ]]; then
            for log in $LARGE_LOGS; do
                sudo truncate -s 0 "$log"
                echo "Truncated $log"
            done
        fi
    else
        echo "No massive logs found."
    fi

    echo -e "\n\033[1;32m✨ Maintenance Complete!\033[0m"
    df -h | grep '^/dev/'
EOF

echo -e "\033[1;36m------------------------------------------------\033[0m"
