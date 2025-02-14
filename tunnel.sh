#!/bin/bash

# Function to check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# Function to prepare tunnel environment
prepare_tunnel_environment() {
    modprobe -r sit 2>/dev/null
    modprobe sit
    sleep 1
    
    # Load necessary modules
    modprobe ipip
    modprobe ip6_tunnel
    modprobe gre
    modprobe ip_gre
    modprobe ip6gre
    
    # Optimize system for tunneling
    sysctl -w net.core.rmem_max=2500000
    sysctl -w net.core.wmem_max=2500000
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
}

# Function to generate random IPv6 address
generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

# Function to generate random IPv4 address
generate_random_ipv4() {
    local prefix=$1
    echo "${prefix}.$((RANDOM % 254 + 1)).$((RANDOM % 254 + 1))"
}

# Function to create IPv6 tunnel
create_ipv6_tunnel() {
    local tunnel_name=$1
    local local_ip=$2
    local remote_ip=$3
    local tunnel_mode=$4

    case $tunnel_mode in
        "sit")
            ip tunnel add ${tunnel_name}_ipv6 mode sit remote $remote_ip local $local_ip ttl 255
            ;;
        "ipip6")
            ip -6 tunnel add ${tunnel_name}_ipv6 mode ipip6 remote $remote_ip local $local_ip ttl 255
            ;;
        "ip6ip6")
            ip -6 tunnel add ${tunnel_name}_ipv6 mode ip6ip6 remote $remote_ip local $local_ip ttl 255
            ;;
    esac

    ip link set ${tunnel_name}_ipv6 up
    ip -6 addr add $(generate_random_ipv6)/64 dev ${tunnel_name}_ipv6
    ip link set dev ${tunnel_name}_ipv6 mtu 1400
}

# Function to create IPv4 tunnel
create_ipv4_tunnel() {
    local tunnel_name=$1
    local local_ipv6=$2
    local remote_ipv6=$3
    local tunnel_mode=$4
    local local_ipv4=$(generate_random_ipv4 "192.168")

    case $tunnel_mode in
        "gre")
            ip -6 tunnel add ${tunnel_name}_ipv4 mode ip6gre remote $remote_ipv6 local $local_ipv6 ttl 255
            ;;
        "ipip")
            ip tunnel add ${tunnel_name}_ipv4 mode ipip remote $remote_ipv6 local $local_ipv6 ttl 255
            ;;
    esac

    ip link set ${tunnel_name}_ipv4 up
    ip addr add $local_ipv4/30 dev ${tunnel_name}_ipv4
    ip link set dev ${tunnel_name}_ipv4 mtu 1360
}

# Function to show tunnel menu
show_tunnel_menu() {
    echo "Select Tunnel Type:"
    echo "1) SIT (IPv6-in-IPv4)"
    echo "2) IPIP6 (IPv4-in-IPv6)"
    echo "3) IP6IP6 (IPv6-in-IPv6)"
    read -p "Enter your choice (1-3): " tunnel_choice

    case $tunnel_choice in
        1) echo "sit" ;;
        2) echo "ipip6" ;;
        3) echo "ip6ip6" ;;
        *) echo "sit" ;;
    esac
}

# Main function
main() {
    check_root
    clear
    echo "=== Advanced Tunnel Setup ==="
    
    prepare_tunnel_environment
    
    # Get IP addresses
    read -p "Enter current server public IP: " LOCAL_IP
    read -p "Enter remote server public IP: " REMOTE_IP
    
    # Choose tunnel mode
    TUNNEL_MODE=$(show_tunnel_menu)
    
    # Set up IPv6 tunnel first
    echo "Setting up IPv6 tunnel..."
    TUNNEL_NAME="tun$(date +%H%M%S)"
    create_ipv6_tunnel "$TUNNEL_NAME" "$LOCAL_IP" "$REMOTE_IP" "$TUNNEL_MODE"
    
    # Get IPv6 addresses
    LOCAL_IPV6=$(ip -6 addr show dev ${TUNNEL_NAME}_ipv6 | grep -oP 'fde8:[a-f0-9:]+')
    
    echo "IPv6 tunnel created successfully!"
    echo "Local IPv6: $LOCAL_IPV6"
    
    # Ask if user wants to create IPv4 tunnel
    read -p "Do you want to create IPv4 tunnel now? (y/n): " create_ipv4
    
    if [[ $create_ipv4 =~ ^[Yy]$ ]]; then
        read -p "Enter remote IPv6 address: " REMOTE_IPV6
        echo "Select IPv4 tunnel type:"
        echo "1) GRE over IPv6"
        echo "2) IPIP"
        read -p "Enter your choice (1-2): " ipv4_choice
        
        IPV4_MODE="gre"
        [[ $ipv4_choice == "2" ]] && IPV4_MODE="ipip"
        
        create_ipv4_tunnel "$TUNNEL_NAME" "$LOCAL_IPV6" "$REMOTE_IPV6" "$IPV4_MODE"
        echo "IPv4 tunnel created successfully!"
    fi

    # Create systemd service
    cat > "/etc/systemd/system/${TUNNEL_NAME}_tunnel.service" <<EOF
[Unit]
Description=Custom Tunnel Service
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash /etc/tunnel_config/${TUNNEL_NAME}_config.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Create config file
    mkdir -p /etc/tunnel_config
    cat > "/etc/tunnel_config/${TUNNEL_NAME}_config.sh" <<EOF
#!/bin/bash
$(declare -f create_ipv6_tunnel)
$(declare -f create_ipv4_tunnel)

prepare_tunnel_environment() {
    modprobe sit
    modprobe ipip
    modprobe ip6_tunnel
    modprobe gre
    modprobe ip_gre
    modprobe ip6gre
}

prepare_tunnel_environment
create_ipv6_tunnel "$TUNNEL_NAME" "$LOCAL_IP" "$REMOTE_IP" "$TUNNEL_MODE"
[[ "$create_ipv4" =~ ^[Yy]$ ]] && create_ipv4_tunnel "$TUNNEL_NAME" "$LOCAL_IPV6" "$REMOTE_IPV6" "$IPV4_MODE"
EOF

    chmod +x "/etc/tunnel_config/${TUNNEL_NAME}_config.sh"
    systemctl daemon-reload
    systemctl enable "${TUNNEL_NAME}_tunnel"
    systemctl start "${TUNNEL_NAME}_tunnel"

    echo -e "\n=== Tunnel Setup Complete ==="
    echo "Tunnel Name: $TUNNEL_NAME"
    echo "IPv6 Mode: $TUNNEL_MODE"
    [[ "$create_ipv4" =~ ^[Yy]$ ]] && echo "IPv4 Mode: $IPV4_MODE"
    echo "Config File: /etc/tunnel_config/${TUNNEL_NAME}_config.sh"
    echo "Service Name: ${TUNNEL_NAME}_tunnel"
}

# Run the script
main
