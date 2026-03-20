#!/usr/bin/env bash

# Default values
USER="root"
IP=""
LOGIC_FILE=""

usage() {
    echo -e "Usage: $0 -i <ip_address> -f <script_file> [-u <user>]"
    echo -e "  -i : Remote IP address"
    echo -e "  -f : Local script file to execute remotely"
    echo -e "  -u : Remote user (default: root)"
    exit 1
}

# Added 'f:' to getopts string
while getopts "i:u:f:" opt; do
  case $opt in
    i) IP="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    f) LOGIC_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validation: Ensure both IP and File are provided and file exists
if [[ -z "$IP" || -z "$LOGIC_FILE" ]]; then
    echo -e "\033[31mError: IP address and Script file are required.\033[0m"
    usage
fi

if [[ ! -f "$LOGIC_FILE" ]]; then
    echo -e "\033[31mError: Script file '$LOGIC_FILE' not found.\033[0m"
    exit 1
fi

clear
echo -e "\033[1;35m🚀 REMOTE RUNNER\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"
echo -e "Target:   ${USER}@${IP}"
echo -e "Script:   ${LOGIC_FILE}"
echo -e "\033[1;36m------------------------------------------------\033[0m"

echo -ne "\033[1m[?] Proceed with execution? (y/n): \033[0m"
read -r choice
[[ "$choice" != "y" && "$choice" != "Y" ]] && echo "Aborted." && exit 1

echo -e "\n\033[1;32m✅ Connecting...\033[0m"

# Execute the provided file
ssh -T "${USER}@${IP}" 'bash -s' < "$LOGIC_FILE"

echo -e "\n\033[1;36m------------------------------------------------\033[0m"
echo "Execution Finished."
