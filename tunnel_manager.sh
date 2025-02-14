#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# System optimization function
optimize_system() {
    echo -e "${BLUE}Optimizing system...${NC}"
    
    # Load required modules
    modprobe -r sit
    modprobe -r gre
    sleep 1
    modprobe sit
    modprobe gre
    
    # Network optimization
    cat > /etc/sysctl.d/99-tunnel.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.default.autoconf=0
net.core.rmem_max=26214400
net.core.wmem_max=26214400
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 87380 16777216
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_no_metrics_save=1
EOF
    sysctl -p /etc/sysctl.d/99-tunnel.conf

    echo -e "${GREEN}System optimization completed${NC}"
}

# Create SIT tunnel function
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    # Reset sit0
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    sleep 1
    
    # Create tunnel
    if ! ip tunnel add ${name} mode sit remote ${remote_ip} local ${local_ip} ttl 255; then
        echo -e "${RED}Failed to create SIT tunnel${NC}"
        return 1
    fi
    
    # Configure tunnel
    ip link set ${name} up
    local local_ipv6=$(printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535)))
    ip -6 addr add ${local_ipv6}/64 dev ${name}
    ip link set dev ${name} mtu 1400
    
    # Add routes
    ip -6 route add fde8:b030::/32 dev ${name}
    ip -6 route add ${local_ipv6}/64 dev ${name}
    
    # Create systemd service
    cat > "/etc/systemd/system/${name}.service" <<EOF
[Unit]
Description=SIT Tunnel Service
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip tunnel add ${name} mode sit remote ${remote_ip} local ${local_ip} ttl 255
ExecStart=/sbin/ip link set ${name} up
ExecStart=/sbin/ip -6 addr add ${local_ipv6}/64 dev ${name}
ExecStart=/sbin/ip link set dev ${name} mtu 1400
ExecStart=/sbin/ip -6 route add fde8:b030::/32 dev ${name}
ExecStart=/sbin/ip -6 route add ${local_ipv6}/64 dev ${name}
ExecStop=/sbin/ip link set ${name} down
ExecStop=/sbin/ip tunnel del ${name}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${name}.service"
    systemctl start "${name}.service"
    
    echo -e "${GREEN}SIT Tunnel created successfully${NC}"
    echo -e "IPv6 Address: ${local_ipv6}"
}

# Create GRE tunnel function
create_gre_tunnel() {
    local name=$1
    local local_ipv6=$2
    local remote_ipv6=$3
    
    # Create tunnel
    if ! ip -6 tunnel add ${name} mode ip6gre remote ${remote_ipv6} local ${local_ipv6} ttl 255; then
        echo -e "${RED}Failed to create GRE tunnel${NC}"
        return 1
    fi
    
    # Configure tunnel
    ip link set ${name} up
    local tunnel_ip="192.168.${RANDOM: -2}.${RANDOM: -2}/24"
    ip addr add ${tunnel_ip} dev ${name}
    ip link set dev ${name} mtu 1360
    
    # Create systemd service
    cat > "/etc/systemd/system/${name}.service" <<EOF
[Unit]
Description=IPv6 GRE Tunnel Service
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip -6 tunnel add ${name} mode ip6gre remote ${remote_ipv6} local ${local_ipv6} ttl 255
ExecStart=/sbin/ip link set ${name} up
ExecStart=/sbin/ip addr add ${tunnel_ip} dev ${name}
ExecStart=/sbin/ip link set dev ${name} mtu 1360
ExecStop=/sbin/ip link set ${name} down
ExecStop=/sbin/ip -6 tunnel del ${name}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${name}.service"
    systemctl start "${name}.service"
    
    echo -e "${GREEN}IPv6 GRE Tunnel created successfully${NC}"
    echo -e "Tunnel IP: ${tunnel_ip}"
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=== Tunnel Manager ===${NC}"
    echo "1) Create SIT Tunnel (IPv6-in-IPv4)"
    echo "2) Create GRE Tunnel (IPv6-over-IPv6)"
    echo "3) Exit"
    echo -e "${BLUE}=====================${NC}"
    
    read -p "Select option (1-3): " choice
    
    case $choice in
        1)
            optimize_system
            read -p "Enter tunnel name: " name
            read -p "Enter local IPv4: " local_ip
            read -p "Enter remote IPv4: " remote_ip
            create_sit_tunnel "$name" "$local_ip" "$remote_ip"
            ;;
        2)
            optimize_system
            read -p "Enter tunnel name: " name
            read -p "Enter local IPv6: " local_ipv6
            read -p "Enter remote IPv6: " remote_ipv6
            create_gre_tunnel "$name" "$local_ipv6" "$remote_ipv6"
            ;;
        3)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
done
