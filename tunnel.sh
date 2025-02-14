#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Function to optimize system
optimize_system() {
    echo -e "${BLUE}Optimizing system for tunneling...${NC}"
    
    # Load necessary modules
    modprobe sit
    modprobe ipip
    modprobe ip6_tunnel
    modprobe gre
    modprobe ip_gre
    modprobe ip6gre
    
    # Optimize network parameters
    cat > /etc/sysctl.d/99-tunnel-optimize.conf <<EOF
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.core.netdev_max_backlog = 5000
EOF
    sysctl -p /etc/sysctl.d/99-tunnel-optimize.conf
}

# Function to generate random IPv6 address
generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

# Function to create SIT tunnel
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    echo -e "${BLUE}Creating SIT tunnel...${NC}"
    
    # Clean up any existing SIT tunnel
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    
    # Create new SIT tunnel
    ip tunnel add ${name}_sit mode sit remote $remote_ip local $local_ip ttl 255
    ip link set ${name}_sit up
    local ipv6_addr=$(generate_random_ipv6)
    ip -6 addr add ${ipv6_addr}/64 dev ${name}_sit
    ip link set dev ${name}_sit mtu 1400
    
    echo -e "${GREEN}SIT tunnel created successfully!${NC}"
    echo "IPv6 Address: ${ipv6_addr}"
    
    # Save tunnel info
    mkdir -p /etc/tunnel_config
    echo "${ipv6_addr}" > "/etc/tunnel_config/${name}_sit_ipv6"
}

# Function to create additional tunnels
create_additional_tunnel() {
    local base_name=$1
    local tunnel_type=$2
    local local_ipv6=$3
    local remote_ipv6=$4
    
    local tunnel_name="${base_name}_${tunnel_type}"
    echo -e "${BLUE}Creating ${tunnel_type} tunnel...${NC}"
    
    case $tunnel_type in
        "gre")
            ip -6 tunnel add $tunnel_name mode ip6gre remote $remote_ipv6 local $local_ipv6 ttl 255
            local ipv4_addr="192.168.${RANDOM % 254 + 1}.${RANDOM % 254 + 1}"
            ip link set $tunnel_name up
            ip addr add ${ipv4_addr}/24 dev $tunnel_name
            ip link set dev $tunnel_name mtu 1360
            ;;
        "ipip6")
            ip -6 tunnel add $tunnel_name mode ipip6 remote $remote_ipv6 local $local_ipv6 ttl 255
            ip link set $tunnel_name up
            local ipv4_addr="10.${RANDOM % 254 + 1}.${RANDOM % 254 + 1}.1"
            ip addr add ${ipv4_addr}/24 dev $tunnel_name
            ;;
        "ip6ip6")
            ip -6 tunnel add $tunnel_name mode ip6ip6 remote $remote_ipv6 local $local_ipv6 ttl 255
            ip link set $tunnel_name up
            local new_ipv6=$(generate_random_ipv6)
            ip -6 addr add ${new_ipv6}/64 dev $tunnel_name
            ;;
    esac
    
    echo -e "${GREEN}${tunnel_type} tunnel created successfully!${NC}"
}

# Function to create systemd service
create_service() {
    local name=$1
    local tunnel_type=$2
    
    cat > "/etc/systemd/system/tunnel_${name}_${tunnel_type}.service" <<EOF
[Unit]
Description=Network Tunnel Service (${tunnel_type})
After=network.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/etc/tunnel_config/${name}_${tunnel_type}_start.sh
ExecStop=/etc/tunnel_config/${name}_${tunnel_type}_stop.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "tunnel_${name}_${tunnel_type}"
    systemctl start "tunnel_${name}_${tunnel_type}"
}

# Main menu
show_menu() {
    clear
    echo -e "${YELLOW}=== Advanced Tunnel Management ===${NC}"
    echo "1) Create SIT Tunnel"
    echo "2) Create Additional Tunnel"
    echo "3) List Active Tunnels"
    echo "4) Remove Tunnel"
    echo "5) System Optimization"
    echo "6) Exit"
    echo -e "${YELLOW}===========================${NC}"
}

# Function to list tunnels
list_tunnels() {
    echo -e "${BLUE}Active Tunnels:${NC}"
    ip tunnel show
    echo -e "\n${BLUE}IPv6 Addresses:${NC}"
    ip -6 addr show
}

# Function to remove tunnel
remove_tunnel() {
    echo "Available tunnels:"
    ip tunnel show
    read -p "Enter tunnel name to remove: " tunnel_name
    
    ip link set $tunnel_name down 2>/dev/null
    ip tunnel del $tunnel_name 2>/dev/null
    systemctl stop "tunnel_${tunnel_name}" 2>/dev/null
    systemctl disable "tunnel_${tunnel_name}" 2>/dev/null
    rm -f "/etc/systemd/system/tunnel_${tunnel_name}.service" 2>/dev/null
    rm -f "/etc/tunnel_config/${tunnel_name}"* 2>/dev/null
    
    echo -e "${GREEN}Tunnel removed successfully${NC}"
}

# Main function
main() {
    check_root
    
    while true; do
        show_menu
        read -p "Select an option: " choice
        
        case $choice in
            1)
                read -p "Enter tunnel name: " tunnel_name
                read -p "Enter local IP: " local_ip
                read -p "Enter remote IP: " remote_ip
                optimize_system
                create_sit_tunnel "$tunnel_name" "$local_ip" "$remote_ip"
                create_service "$tunnel_name" "sit"
                ;;
            2)
                if [[ ! -f /etc/tunnel_config/*_sit_ipv6 ]]; then
                    echo -e "${RED}No SIT tunnel found. Create SIT tunnel first.${NC}"
                    continue
                fi
                
                echo "Select tunnel type:"
                echo "1) GRE over IPv6"
                echo "2) IPIP6"
                echo "3) IP6IP6"
                read -p "Enter choice (1-3): " tunnel_choice
                
                read -p "Enter base tunnel name: " tunnel_name
                read -p "Enter remote IPv6 address: " remote_ipv6
                local local_ipv6=$(cat /etc/tunnel_config/${tunnel_name}_sit_ipv6)
                
                case $tunnel_choice in
                    1) create_additional_tunnel "$tunnel_name" "gre" "$local_ipv6" "$remote_ipv6" ;;
                    2) create_additional_tunnel "$tunnel_name" "ipip6" "$local_ipv6" "$remote_ipv6" ;;
                    3) create_additional_tunnel "$tunnel_name" "ip6ip6" "$local_ipv6" "$remote_ipv6" ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;
            3)
                list_tunnels
                ;;
            4)
                remove_tunnel
                ;;
            5)
                optimize_system
                ;;
            6)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        read -p "Press enter to continue..."
    done
}

# Run the script
main
