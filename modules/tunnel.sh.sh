#!/bin/bash

# Prepare system for tunneling
prepare_tunnel_system() {
    echo "Preparing system for tunnel creation..."
    
    # Unload and reload required modules
    modprobe -r sit
    modprobe -r gre
    sleep 1
    modprobe sit
    modprobe gre
    sleep 1
    
    # Reset interfaces
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    
    # Optimize network settings
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.accept_ra=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.all.autoconf=0 >/dev/null 2>&1
}

# Create SIT tunnel
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    echo "Creating SIT tunnel..."
    
    # Validate inputs
    if ! validate_ip "$local_ip" || ! validate_ip "$remote_ip"; then
        echo -e "${RED}Invalid IP address format${NC}"
        return 1
    }
    
    # Prepare system
    prepare_tunnel_system
    
    # Create tunnel
    if ! ip tunnel add ${name} mode sit remote ${remote_ip} local ${local_ip} ttl 255; then
        echo -e "${RED}Failed to create tunnel${NC}"
        return 1
    fi
    
    # Configure tunnel
    ip link set ${name} up
    local local_ipv6=$(generate_random_ipv6)
    ip -6 addr add ${local_ipv6}/64 dev ${name}
    ip link set dev ${name} mtu 1400
    
    # Add routes
    ip -6 route add fde8:b030::/32 dev ${name}
    
    echo -e "${GREEN}SIT Tunnel created successfully${NC}"
    echo -e "Tunnel name: ${name}"
    echo -e "IPv6 address: ${local_ipv6}"
    
    # Save tunnel configuration
    save_tunnel_config "$name" "sit" "$local_ip" "$remote_ip" "$local_ipv6"
}

# Create GRE tunnel
create_gre_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    echo "Creating GRE tunnel..."
    
    # Validate inputs
    if ! validate_ip "$local_ip" || ! validate_ip "$remote_ip"; then
        echo -e "${RED}Invalid IP address format${NC}"
        return 1
    }
    
    # Prepare system
    prepare_tunnel_system
    
    # Create tunnel
    if ! ip tunnel add ${name} mode gre remote ${remote_ip} local ${local_ip} ttl 255; then
        echo -e "${RED}Failed to create tunnel${NC}"
        return 1
    fi
    
    # Configure tunnel
    ip link set ${name} up
    local tunnel_ip="192.168.${RANDOM: -2}.${RANDOM: -2}/24"
    ip addr add ${tunnel_ip} dev ${name}
    ip link set dev ${name} mtu 1400
    
    echo -e "${GREEN}GRE Tunnel created successfully${NC}"
    echo -e "Tunnel name: ${name}"
    echo -e "Tunnel IP: ${tunnel_ip}"
    
    # Save tunnel configuration
    save_tunnel_config "$name" "gre" "$local_ip" "$remote_ip" "$tunnel_ip"
}

# Save tunnel configuration
save_tunnel_config() {
    local name=$1
    local type=$2
    local local_ip=$3
    local remote_ip=$4
    local tunnel_ip=$5
    
    mkdir -p /etc/tunnel-manager/tunnels
    cat > "/etc/tunnel-manager/tunnels/${name}.conf" <<EOF
TYPE=$type
LOCAL_IP=$local_ip
REMOTE_IP=$remote_ip
TUNNEL_IP=$tunnel_ip
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF
}

# List active tunnels
list_tunnels() {
    echo -e "${BLUE}Active Tunnels:${NC}"
    ip tunnel show
    
    echo -e "\n${BLUE}IPv6 Addresses:${NC}"
    ip -6 addr show
    
    echo -e "\n${BLUE}IPv4 Addresses:${NC}"
    ip addr show | grep -v inet6
}

# Test tunnel connection
test_tunnel_connection() {
    echo -e "${BLUE}Available tunnels:${NC}"
    ip tunnel show
    read -p "Enter tunnel name to test: " tunnel_name
    
    if [[ -z "$tunnel_name" ]]; then
        echo -e "${RED}Invalid tunnel name${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}Testing tunnel ${tunnel_name}...${NC}"
    
    # Get tunnel info
    local config_file="/etc/tunnel-manager/tunnels/${tunnel_name}.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        
        # Test based on tunnel type
        case $TYPE in
            "sit")
                echo "Testing IPv6 connectivity..."
                ping6 -c 4 ${TUNNEL_IP%/*}
                ;;
            "gre")
                echo "Testing IPv4 connectivity..."
                ping -c 4 ${TUNNEL_IP%/*}
                ;;
        esac
    else
        echo -e "${RED}Tunnel configuration not found${NC}"
    fi
    
    # Show tunnel status
    ip link show ${tunnel_name}
    ip addr show ${tunnel_name}
}

# Delete tunnel
delete_tunnel_menu() {
    echo -e "${BLUE}Available tunnels:${NC}"
    ip tunnel show
    read -p "Enter tunnel name to delete: " tunnel_name
    
    if [[ -z "$tunnel_name" ]]; then
        echo -e "${RED}Invalid tunnel name${NC}"
        return 1
    fi
    
    # Delete tunnel
    ip link set ${tunnel_name} down
    ip tunnel del ${tunnel_name}
    rm -f "/etc/tunnel-manager/tunnels/${tunnel_name}.conf"
    
    echo -e "${GREEN}Tunnel ${tunnel_name} deleted successfully${NC}"
}

# Monitor tunnel
monitor_tunnel_menu() {
    echo -e "${BLUE}Available tunnels:${NC}"
    ip tunnel show
    read -p "Enter tunnel name to monitor: " tunnel_name
    
    if [[ -z "$tunnel_name" ]]; then
        echo -e "${RED}Invalid tunnel name${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}Monitoring tunnel ${tunnel_name}...${NC}"
    echo "Press Ctrl+C to stop monitoring"
    
    while true; do
        clear
        echo -e "${BLUE}Tunnel Status:${NC}"
        ip -s link show ${tunnel_name}
        echo -e "\n${BLUE}Traffic Statistics:${NC}"
        ip -s tunnel show ${tunnel_name}
        sleep 2
    done
}
