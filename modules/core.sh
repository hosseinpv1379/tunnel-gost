#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create SIT tunnel function
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    echo "Preparing system..."
    modprobe -r sit
    sleep 1
    modprobe sit
    sleep 1
    
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    sleep 1
    
    echo "Creating tunnel..."
    if ! ip tunnel add ${name} mode sit remote ${remote_ip} local ${local_ip} ttl 255; then
        echo -e "${RED}Failed to create tunnel${NC}"
        return 1
    fi
    
    ip link set ${name} up
    local local_ipv6=$(printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535)))
    ip -6 addr add ${local_ipv6}/64 dev ${name}
    ip link set dev ${name} mtu 1400
    
    ip -6 route add fde8:b030::/32 dev ${name}
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
    
    echo -e "${GREEN}Tunnel created successfully${NC}"
    echo -e "IPv6: ${local_ipv6}"
}

# List tunnels function
list_tunnels() {
    echo -e "${BLUE}Active tunnels:${NC}"
    ip tunnel show
    echo -e "\n${BLUE}IPv6 addresses:${NC}"
    ip -6 addr show
}

# Delete tunnel function
delete_tunnel() {
    local tunnel_name=$1
    ip link set ${tunnel_name} down
    ip tunnel del ${tunnel_name}
    echo -e "${GREEN}Tunnel deleted${NC}"
}

# Test tunnel function
test_tunnel() {
    local tunnel_name=$1
    ip link show ${tunnel_name}
    ip addr show ${tunnel_name}
}
