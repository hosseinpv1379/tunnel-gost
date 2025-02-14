#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Initialize system
init_system() {
    # Load required modules
    for module in sit gre ipip ip6_tunnel ip_gre; do
        modprobe $module 2>/dev/null
    done

    # Enable IPv4/IPv6 forwarding
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1
}

# Generate random IPv6 address
generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

# Validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 || $octet -lt 0 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}
