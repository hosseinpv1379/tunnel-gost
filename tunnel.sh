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
    # Remove and reload sit module
    modprobe -r sit
    sleep 1
    modprobe sit
    sleep 1

    # Reset sit0 to default state
    ip link set sit0 down 2>/dev/null
    ip tunnel change sit0 mode sit remote any local any ttl 64
    ip link set sit0 up

    # Increase system limits
    sysctl -w net.core.rmem_max=2500000
    sysctl -w net.core.wmem_max=2500000
    echo 1000000 > /proc/sys/net/core/rmem_default
    echo 1000000 > /proc/sys/net/core/wmem_default
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

# Function to create systemd service
create_systemd_service() {
    local tunnel_name=$1
    local config_file=$2

    cat > "/etc/systemd/system/${tunnel_name}_tunnel.service" <<EOF
[Unit]
Description=IPv6/IPv4 Tunnel Service for ${tunnel_name}
After=network.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash $config_file
ExecStop=/bin/bash -c "ip link set ${tunnel_name}_ipv4 down; ip link set ${tunnel_name}_ipv6 down"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${tunnel_name}_tunnel"
    systemctl start "${tunnel_name}_tunnel"
}

# Function to show existing tunnels
show_existing_tunnels() {
    echo "=== Existing Tunnels ==="
    ip tunnel show
    echo "------------------------"
}

# Function to create a single tunnel
create_tunnel() {
    local tunnel_number=$1
    local LOCAL_IP=$2
    local REMOTE_IP=$3

    # Generate tunnel name with number
    local TUNNEL_NAME="tun${tunnel_number}"
    
    # Generate random IPs
    local LOCAL_IPV6=$(generate_random_ipv6)
    local REMOTE_IPV6=$(generate_random_ipv6)
    local LOCAL_PRIV_IP=$(generate_random_ipv4 "192.168")
    local REMOTE_PRIV_IP=$(generate_random_ipv4 "192.168")

    # Create config directory and file
    mkdir -p /etc/tunnel_config
    local CONFIG_FILE="/etc/tunnel_config/${TUNNEL_NAME}_config.sh"

    # Create config file
    cat > "$CONFIG_FILE" <<EOF
#!/bin/bash

# IPv6 Tunnel Setup
ip tunnel add ${TUNNEL_NAME}_ipv6 mode sit remote $REMOTE_IP local $LOCAL_IP ttl 255 || {
    ip link set ${TUNNEL_NAME}_ipv6 down 2>/dev/null
    ip tunnel del ${TUNNEL_NAME}_ipv6 2>/dev/null
    sleep 2
    ip tunnel add ${TUNNEL_NAME}_ipv6 mode sit remote $REMOTE_IP local $LOCAL_IP ttl 255
}

ip link set ${TUNNEL_NAME}_ipv6 up
ip -6 addr add $LOCAL_IPV6/64 dev ${TUNNEL_NAME}_ipv6
ip link set dev ${TUNNEL_NAME}_ipv6 mtu 1400

# IPv6 Routing
ip -6 route add $REMOTE_IPV6/128 dev ${TUNNEL_NAME}_ipv6
ip -6 route add fde8:b030::/32 dev ${TUNNEL_NAME}_ipv6

# GRE Tunnel Setup
ip -6 tunnel add ${TUNNEL_NAME}_ipv4 mode ip6gre remote $REMOTE_IPV6 local $LOCAL_IPV6 ttl 255
ip link set ${TUNNEL_NAME}_ipv4 up
ip addr add $LOCAL_PRIV_IP/30 dev ${TUNNEL_NAME}_ipv4
ip link set dev ${TUNNEL_NAME}_ipv4 mtu 1360

# IPv4 Routing
ip route add $REMOTE_PRIV_IP/32 dev ${TUNNEL_NAME}_ipv4

# System Settings
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv6.conf.all.accept_redirects=0
sysctl -w net.ipv6.conf.all.accept_ra=0
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0
sysctl -w net.ipv4.conf.all.accept_redirects=0
sysctl -w net.ipv4.conf.all.send_redirects=0
EOF

    # Execute config
    chmod +x "$CONFIG_FILE"
    bash "$CONFIG_FILE"

    # Create systemd service
    create_systemd_service "$TUNNEL_NAME" "$CONFIG_FILE"

    # Display tunnel information
    echo -e "\n=== Tunnel $tunnel_number Information ==="
    echo "Tunnel Name: $TUNNEL_NAME"
    echo "Local IPv6: $LOCAL_IPV6"
    echo "Remote IPv6: $REMOTE_IPV6"
    echo "Local IPv4: $LOCAL_PRIV_IP"
    echo "Remote IPv4: $REMOTE_PRIV_IP"
    echo "Config File: $CONFIG_FILE"
}

# Main function
main() {
    check_root
    clear
    echo "=== Multiple IPv6/IPv4 Tunnel Setup ==="
    
    # Show existing tunnels
    show_existing_tunnels
    
    # Prepare environment
    prepare_tunnel_environment

    # Get IP addresses
    read -p "Enter current server public IP: " LOCAL_IP
    read -p "Enter remote server public IP: " REMOTE_IP
    read -p "How many tunnels do you want to create? " TUNNEL_COUNT

    # Validate inputs
    if ! [[ $TUNNEL_COUNT =~ ^[0-9]+$ ]] || [ $TUNNEL_COUNT -lt 1 ]; then
        echo "Invalid number of tunnels"
        exit 1
    fi

    # Create tunnels
    for ((i=1; i<=$TUNNEL_COUNT; i++)); do
        echo -e "\nCreating tunnel $i of $TUNNEL_COUNT..."
        create_tunnel $i "$LOCAL_IP" "$REMOTE_IP"
    done

    echo -e "\nAll tunnels have been created successfully!"
    echo "To check status use: systemctl status tunX_tunnel"
    echo "To view logs use: journalctl -u tunX_tunnel"
    echo "Where X is the tunnel number (1 to $TUNNEL_COUNT)"
}

# Run the script
main
