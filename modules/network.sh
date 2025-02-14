#!/bin/bash

# Network functions for tunnel creation

# Create SIT tunnel function
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    # Create tunnel
    ip tunnel add ${name} mode sit remote ${remote_ip} local ${local_ip} ttl 255
    ip link set ${name} up
    
    # Generate IPv6 addresses
    local local_ipv6=$(generate_random_ipv6)
    ip -6 addr add ${local_ipv6}/64 dev ${name}
    
    # Set MTU
    ip link set dev ${name} mtu 1400
    
    # Add IPv6 routes
    ip -6 route add fde8:b030::/32 dev ${name}
    
    echo -e "${GREEN}SIT Tunnel created successfully${NC}"
    echo -e "Local IPv6: ${local_ipv6}"
}

# Create GRE tunnel function
create_gre_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    # Create tunnel
    ip tunnel add ${name} mode gre remote ${remote_ip} local ${local_ip} ttl 255
    ip link set ${name} up
    
    # Add IPv4 address
    local tunnel_ip=$(generate_random_ipv4)
    ip addr add ${tunnel_ip}/24 dev ${name}
    
    # Set MTU
    ip link set dev ${name} mtu 1400
    
    echo -e "${GREEN}GRE Tunnel created successfully${NC}"
    echo -e "Tunnel IP: ${tunnel_ip}"
}

# Create IPIP tunnel function
create_ipip_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    # Create tunnel
    ip tunnel add ${name} mode ipip remote ${remote_ip} local ${local_ip} ttl 255
    ip link set ${name} up
    
    # Add IPv4 address
    local tunnel_ip=$(generate_random_ipv4)
    ip addr add ${tunnel_ip}/24 dev ${name}
    
    # Set MTU
    ip link set dev ${name} mtu 1400
    
    echo -e "${GREEN}IPIP Tunnel created successfully${NC}"
    echo -e "Tunnel IP: ${tunnel_ip}"
}

# Generate random IPv6 address
generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

# Generate random IPv4 address
generate_random_ipv4() {
    printf "192.168.%d.%d" $((RANDOM % 254 + 1)) $((RANDOM % 254 + 1))
}

# Validate IP address
validate_ip() {
    local ip=$1
    local type=$2
    
    case $type in
        "ipv4")
            if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                return 0
            fi
            ;;
        "ipv6")
            if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
                return 0
            fi
            ;;
    esac
}
    return 1
