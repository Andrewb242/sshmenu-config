#!/usr/bin/env bash

# ============================
# SSH Server Upgrade Script
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

clear
echo -e "\033[1;33m⚠️  PRE-UPGRADE CHECKLIST for ${USER}@${IP}\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"

CHECKLIST=(
    "Have you redirected Production traffic to a maintenance screen?"
    "Have you taken a snapshot/backup of the VPS?"
    "Do you want to STOP all Docker containers before upgrading?"
)

ask_confirm() {
    while true; do
        echo -ne "\033[1m[ ] $1 (y/n): \033[0m"
        read -r choice
        case "$choice" in
            y|Y ) return 0;;
            n|N ) return 1;;
            * ) echo "Please press y or n.";;
        esac
    done
}

for ((i=0; i<${#CHECKLIST[@]}-1; i++)); do
    ask_confirm "${CHECKLIST[$i]}" || { echo -e "\033[31mUpgrade aborted.\033[0m"; exit 1; }
done

STOP_DOCKER=false
if ask_confirm "${CHECKLIST[2]}"; then
    STOP_DOCKER=true
fi

echo -e "\n\033[1;32m✅ Checklist complete. Connecting to server...\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"

ssh -tt "${USER}@${IP}" bash -s << EOF
    # 1. Prevent Docker from updating
    echo -e "\033[1;33m[!] Holding Docker packages to prevent updates...\033[0m"
    sudo apt-mark hold docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null

    if [ "$STOP_DOCKER" = true ]; then
        if command -v docker >/dev/null 2>&1; then
            echo -e "\033[1;33m[!] Stopping all Docker containers...\033[0m"
            docker stop \$(docker ps -q) 2>/dev/null
        fi
    fi

    echo -e "\033[1;34m1. Updating package lists...\033[0m"
    sudo apt-get update

    echo -e "\n\033[1;34m2. Performing upgrade (excluding Docker)...\033[0m"
    sudo apt-get upgrade -y

    echo -e "\n\033[1;34m3. Cleaning up...\033[0m"
    sudo apt-get autoremove -y

    # 4. Optional: Unhold Docker if you only wanted to skip it for THIS session
    # sudo apt-mark unhold docker-ce docker-ce-cli containerd.io docker-compose-plugin

    if [ -f /var/run/reboot-required ]; then
        echo -e "\n\033[1;31m[!] REBOOT REQUIRED to finish updates.\033[0m"
        echo -n "Would you like to reboot now? (y/n): "
        read -r res
        if [[ "\$res" == "y" || "\$res" == "Y" ]]; then
            echo -e "\033[1;33mRebooting server now. Connection will close.\033[0m"
            sudo reboot
        else
            echo -e "\033[1;32mUpgrade finished. Please reboot manually later.\033[0m"
        fi
    else
        echo -e "\n\033[1;32m🚀 Upgrade Finished! No reboot required.\033[0m"
        if [ "$STOP_DOCKER" = true ]; then
            echo -n "Would you like to restart Docker containers now? (y/n): "
            read -r res
            if [[ "\$res" == "y" || "\$res" == "Y" ]]; then
                docker start \$(docker ps -a -q)
            fi
        fi
    fi
EOF

echo -e "\n\033[1;36m------------------------------------------------\033[0m"
echo -e "Press Enter to return to menu."
read
