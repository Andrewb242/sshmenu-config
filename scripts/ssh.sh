
#!/usr/bin/env bash

# ============================
# SSH Dynamic Tunnel Script
# ============================

# Default settings
USER="root"
IP=""
TUNNELS=()

usage() {
    echo -e "Usage: $0 -i <ip_address> [-p <local:remote>] [-u <user>]"
    echo -e "\nOptions:"
    echo -e "  -i    IP address of the remote server (Required)"
    echo -e "  -p    Port mapping (LocalPort:RemotePort). Optional. Can be used multiple times."
    echo -e "  -u    Username (Optional, default: root)"
    exit 1
}

# Parse flags
while getopts "i:p:u:" opt; do
  case $opt in
    i) IP="$OPTARG" ;;
    p) TUNNELS+=("$OPTARG") ;;
    u) USER="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validation: Only IP is strictly required now
if [[ -z "$IP" ]]; then
    echo -e "\033[31mError: IP address (-i) is required.\033[0m"
    usage
fi

# Build the command
SSH_CMD="ssh"

# If tunnels exist, add the -L flags
if [ ${#TUNNELS[@]} -gt 0 ]; then
    echo -e "\033[1;32m⚡ Establishing Tunnels...\033[0m"
    for mapping in "${TUNNELS[@]}"; do
        LOCAL_PORT=$(echo "$mapping" | cut -d':' -f1)
        REMOTE_PORT=$(echo "$mapping" | cut -d':' -f2)
        SSH_CMD="$SSH_CMD -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
    done
else
    echo -e "\033[1;32m💻 Starting Standard SSH Session...\033[0m"
fi

# Finalize command
SSH_CMD="$SSH_CMD ${USER}@${IP}"

# Visual output
echo -e "\033[90mCommand: $SSH_CMD\033[0m"
echo -e "\033[1;36m------------------------------------\033[0m"

# Execute
eval "$SSH_CMD"
