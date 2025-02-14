#!/bin/bash

# Core module for Tunnel Manager
# Handles basic system functions and initialization

# Global variables
declare -A TUNNEL_TYPES=(
    ["sit"]="IPv6-in-IPv4 Tunnel"
    ["ipip"]="IPv4-in-IPv4 Tunnel"
    ["gre"]="GRE Tunnel"
    ["gretap"]="GRETAP Tunnel"
    ["ip6gre"]="IPv6 GRE Tunnel"
    ["ipip6"]="IPv4-in-IPv6 Tunnel"
    ["ip6ip6"]="IPv6-in-IPv6 Tunnel"
)

# Required kernel modules
REQUIRED_MODULES=(
    "sit"
    "ipip"
    "gre"
    "ip6_tunnel"
    "ip_gre"
    "ip6gre"
    "xfrm4_tunnel"
    "xfrm6_tunnel"
)

# System initialization
init_system() {
    check_root
    load_modules
    optimize_system
    init_directories
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

# Load required kernel modules
load_modules() {
    for module in "${REQUIRED_MODULES[@]}"; do
        if ! lsmod | grep -q "^$module"; then
            modprobe $module
            log "INFO" "Loaded kernel module: $module"
        fi
    done
}

# Optimize system for tunneling
optimize_system() {
    cat > /etc/sysctl.d/99-tunnel-optimize.conf <<EOF
# Network Buffer Optimization
net.core.rmem_max = 26214400
net.core.wmem_max = 26214400
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216

# IPv4 Configuration
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0

# IPv6 Configuration
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# TCP Optimization
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_congestion_control = cubic
net.core.netdev_max_backlog = 16384
EOF

    sysctl -p /etc/sysctl.d/99-tunnel-optimize.conf
}

# Initialize directories
init_directories() {
    mkdir -p "/etc/tunnel-manager/tunnels"
    mkdir -p "/var/log/tunnel-manager"
    mkdir -p "/var/run/tunnel-manager"
}
