#!/usr/bin/env bash

# ============================
# SSH Advanced Firewall Script
# ============================

USER="root"
IP=""

# --- DEFINE YOUR RULESETS HERE ---
# Use COMMAS (,) to separate rules within a profile.
# This allows spaces inside a single rule (like IP-specific rules).
declare -A RULESETS
RULESETS=(
    ["default"]="ssh,http,https"
    ["ezer-server"]="ssh, 45876/tcp"
    ["disable"]="DISABLE_FIREWALL"
)

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
echo -e "\033[1;33m🛡️  Firewall Management for ${USER}@${IP}\033[0m"
echo -e "\033[1;36m------------------------------------------------\033[0m"
echo -e "Select a firewall profile to deploy:"

# Menu selection
PS3="Please enter your choice (1-${#RULESETS[@]}): "
options=("${!RULESETS[@]}")

select opt in "${options[@]}"; do
    if [[ -n "$opt" ]]; then
        SELECTED_PROFILE=$opt
        SELECTED_RULES=${RULESETS[$opt]}
        break
    else
        echo "Invalid selection."
    fi
done

echo -e "\n\033[1;32mSelected Profile: [$SELECTED_PROFILE]\033[0m"

if [[ "$SELECTED_RULES" == "DISABLE_FIREWALL" ]]; then
    echo -e "\033[1;31m⚠️  WARNING: You are about to DISABLE the firewall.\033[0m"
    read -p "Are you sure? (y/n): " confirm
    [[ "$confirm" != "y" ]] && exit 1
fi

echo -e "\033[1;34mConnecting to server...\033[0m"

# -T for clean output
ssh -T "${USER}@${IP}" bash -s -- "$SELECTED_RULES" << 'EOF'
    RULES_STRING="$1"

    if [[ "$RULES_STRING" == "DISABLE_FIREWALL" ]]; then
        sudo ufw disable
        sudo ufw default allow incoming
        echo -e "\n\033[1;32m✅ Firewall disabled.\033[0m"
    else
        # Install UFW if missing
        sudo apt-get update -qq && sudo apt-get install -y ufw > /dev/null

        # Reset UFW to default state
        echo "y" | sudo ufw reset > /dev/null
        sudo ufw default deny incoming
        sudo ufw default allow outgoing

        echo -e "\033[1;34mApplying rules...\033[0m"

        # --- FIX START ---
        # We use Internal Field Separator (IFS) to handle the splitting naturally.
        # This avoids pipes and subshells which can break variable expansion.

        # Save original IFS
        OIFS="$IFS"
        # Set IFS to comma only
        IFS=','

        # Disable globbing so asterisks (*) in rules don't expand to filenames
        set -f

        # Read the string into an array called 'rule_array'
        read -a rule_array <<< "$RULES_STRING"

        # Restore original IFS and globbing immediately
        set +f
        IFS="$OIFS"

        # Loop through the array
        for rule in "${rule_array[@]}"; do

            # Pure Bash trim (removes leading/trailing spaces without xargs/sed)
            # This removes the dependency on external tools that might fail
            rule="${rule#"${rule%%[![:space:]]*}"}"
            rule="${rule%"${rule##*[![:space:]]}"}"

            if [[ -n "$rule" ]]; then
                # Debug print with quotes to confirm we have the whole string
                echo "   [+] Applying: ufw allow '$rule'"

                # Execute
                sudo ufw allow $rule
            fi
        done
        # --- FIX END ---

        # Enable firewall
        echo "y" | sudo ufw enable
        echo -e "\n\033[1;32m✅ Firewall active and updated!\033[0m"
    fi

    echo -e "\033[1;36mCurrent Status:\033[0m"
    sudo ufw status numbered
EOF
