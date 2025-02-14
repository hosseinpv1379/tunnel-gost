#!/bin/bash

###########################################
# Advanced Tunnel Management System       #
# Version: 1.0                           #
# Author: AI Assistant                   #
###########################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
TUNNEL_CONFIG_DIR="/etc/tunnel_config"
TUNNEL_LOG_DIR="/var/log/tunnels"
BACKUP_DIR="/var/backup/tunnels"
SCRIPT_LOG="/var/log/tunnel_manager.log"
MTU_DEFAULT=1500
KERNEL_MODULES=(
    "sit"
    "ipip"
    "ip6_tunnel"
    "gre"
    "ip_gre"
    "ip6gre"
    "xfrm4_tunnel"
    "xfrm6_tunnel"
    "tunnel4"
    "tunnel6"
    "vti"
    "xfrm_interface"
)

# Logger function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" >> "$SCRIPT_LOG"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR] ${message}${NC}" ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING] ${message}${NC}" ;;
        "INFO")
            echo -e "${BLUE}[INFO] ${message}${NC}" ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS] ${message}${NC}" ;;
    esac
}

# System initialization
init_system() {
    log "INFO" "Initializing tunnel management system..."
    
    # Create necessary directories
    for dir in "$TUNNEL_CONFIG_DIR" "$TUNNEL_LOG_DIR" "$BACKUP_DIR"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "INFO" "Created directory: $dir"
        fi
    done

    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        exit 1
    fi
}

# System optimization
optimize_system() {
    log "INFO" "Optimizing system for tunneling..."
    
    # Create sysctl configuration
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
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# IPv6 Configuration
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# TCP Optimization
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_congestion_control = cubic
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_max_syn_backlog = 8192

# Network Queue Configuration
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_max_tw_buckets = 1440000
EOF

    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-tunnel-optimize.conf

    # Load kernel modules
    for module in "${KERNEL_MODULES[@]}"; do
        if ! lsmod | grep -q "^$module"; then
            modprobe $module
            log "INFO" "Loaded kernel module: $module"
        fi
    done
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    local ip_type=$2

    if [[ $ip_type == "ipv4" ]]; then
        if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            IFS='.' read -r -a octets <<< "$ip"
            for octet in "${octets[@]}"; do
                if [[ $octet -gt 255 || $octet -lt 0 ]]; then
                    return 1
                fi
            done
            return 0
        fi
        return 1
    elif [[ $ip_type == "ipv6" ]]; then
        if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
            return 0
        fi
        return 1
    fi
    return 1
}

# Function to generate random IPv6 address
generate_random_ipv6() {
    local prefix=$1
    [[ -z $prefix ]] && prefix="fde8:b030"
    printf "${prefix}:%x:%x:%x:%x" $((RANDOM % 65535)) $((RANDOM % 65535)) $((RANDOM % 65535)) $((RANDOM % 65535))
}

# Function to generate random IPv4 address
generate_random_ipv4() {
    local prefix=$1
    [[ -z $prefix ]] && prefix="192.168"
    echo "${prefix}.$((RANDOM % 254 + 1)).$((RANDOM % 254 + 1))"
}

# Function to check network interface
check_interface() {
    local interface=$1
    if ! ip link show "$interface" &>/dev/null; then
        return 1
    fi
    return 0
}

# Function to backup tunnel configuration
backup_config() {
    local backup_name="tunnel_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_file="${BACKUP_DIR}/${backup_name}.tar.gz"
    
    tar -czf "$backup_file" -C / \
        etc/tunnel_config \
        etc/systemd/system/tunnel_* \
        var/log/tunnels \
        2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Backup created successfully: $backup_file"
        return 0
    else
        log "ERROR" "Failed to create backup"
        return 1
    fi
}

# Function to restore tunnel configuration
restore_config() {
    local backup_file=$1
    if [[ ! -f "$backup_file" ]]; then
        log "ERROR" "Backup file not found: $backup_file"
        return 1
    fi
    
    tar -xzf "$backup_file" -C /
    if [[ $? -eq 0 ]]; then
        systemctl daemon-reload
        log "SUCCESS" "Configuration restored successfully"
        return 0
    else
        log "ERROR" "Failed to restore configuration"
        return 1
    fi
}# Tunnel Types and Configuration Functions
declare -A TUNNEL_TYPES=(
    ["sit"]="IPv6-in-IPv4 Tunnel"
    ["ipip"]="IPv4-in-IPv4 Tunnel"
    ["gre"]="GRE Tunnel"
    ["gretap"]="GRETAP Tunnel"
    ["ip6gre"]="IPv6 GRE Tunnel"
    ["ipip6"]="IPv4-in-IPv6 Tunnel"
    ["ip6ip6"]="IPv6-in-IPv6 Tunnel"
    ["vti"]="Virtual Tunnel Interface"
    ["xfrm"]="XFRM Interface"
)

# Create SIT Tunnel
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    local mtu=${4:-1400}

    log "INFO" "Creating SIT tunnel: $name"

    # Prepare environment
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    sleep 1

    # Create tunnel
    if ! ip tunnel add ${name} mode sit remote $remote_ip local $local_ip ttl 255; then
        log "ERROR" "Failed to create SIT tunnel: $name"
        return 1
    fi

    # Configure tunnel
    ip link set ${name} up
    ip link set dev ${name} mtu $mtu
    local ipv6_addr=$(generate_random_ipv6)
    ip -6 addr add ${ipv6_addr}/64 dev ${name}

    # Save configuration
    mkdir -p "${TUNNEL_CONFIG_DIR}/${name}"
    cat > "${TUNNEL_CONFIG_DIR}/${name}/config" <<EOF
TYPE=sit
LOCAL_IP=$local_ip
REMOTE_IP=$remote_ip
IPv6_ADDR=$ipv6_addr
MTU=$mtu
EOF

    log "SUCCESS" "SIT tunnel created: $name (IPv6: $ipv6_addr)"
    return 0
}

# Create IPIP Tunnel
create_ipip_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    local mtu=${4:-1400}

    log "INFO" "Creating IPIP tunnel: $name"

    # Create tunnel
    if ! ip tunnel add ${name} mode ipip remote $remote_ip local $local_ip ttl 255; then
        log "ERROR" "Failed to create IPIP tunnel: $name"
        return 1
    fi

    # Configure tunnel
    ip link set ${name} up
    ip link set dev ${name} mtu $mtu
    local ipv4_addr=$(generate_random_ipv4)
    ip addr add ${ipv4_addr}/24 dev ${name}

    # Save configuration
    mkdir -p "${TUNNEL_CONFIG_DIR}/${name}"
    cat > "${TUNNEL_CONFIG_DIR}/${name}/config" <<EOF
TYPE=ipip
LOCAL_IP=$local_ip
REMOTE_IP=$remote_ip
IPv4_ADDR=$ipv4_addr
MTU=$mtu
EOF

    log "SUCCESS" "IPIP tunnel created: $name (IPv4: $ipv4_addr)"
    return 0
}

# Create GRE Tunnel
create_gre_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    local key=${4:-0}
    local mtu=${5:-1400}

    log "INFO" "Creating GRE tunnel: $name"

    # Create tunnel
    if ! ip tunnel add ${name} mode gre remote $remote_ip local $local_ip ttl 255 key $key; then
        log "ERROR" "Failed to create GRE tunnel: $name"
        return 1
    fi

    # Configure tunnel
    ip link set ${name} up
    ip link set dev ${name} mtu $mtu
    local ipv4_addr=$(generate_random_ipv4)
    ip addr add ${ipv4_addr}/24 dev ${name}

    # Save configuration
    mkdir -p "${TUNNEL_CONFIG_DIR}/${name}"
    cat > "${TUNNEL_CONFIG_DIR}/${name}/config" <<EOF
TYPE=gre
LOCAL_IP=$local_ip
REMOTE_IP=$remote_ip
IPv4_ADDR=$ipv4_addr
KEY=$key
MTU=$mtu
EOF

    log "SUCCESS" "GRE tunnel created: $name (IPv4: $ipv4_addr)"
    return 0
}

# Create IP6GRE Tunnel
create_ip6gre_tunnel() {
    local name=$1
    local local_ip6=$2
    local remote_ip6=$3
    local mtu=${4:-1400}

    log "INFO" "Creating IP6GRE tunnel: $name"

    # Create tunnel
    if ! ip -6 tunnel add ${name} mode ip6gre remote $remote_ip6 local $local_ip6 ttl 255; then
        log "ERROR" "Failed to create IP6GRE tunnel: $name"
        return 1
    fi

    # Configure tunnel
    ip link set ${name} up
    ip link set dev ${name} mtu $mtu
    local ipv4_addr=$(generate_random_ipv4)
    ip addr add ${ipv4_addr}/24 dev ${name}

    # Save configuration
    mkdir -p "${TUNNEL_CONFIG_DIR}/${name}"
    cat > "${TUNNEL_CONFIG_DIR}/${name}/config" <<EOF
TYPE=ip6gre
LOCAL_IPv6=$local_ip6
REMOTE_IPv6=$remote_ip6
IPv4_ADDR=$ipv4_addr
MTU=$mtu
EOF

    log "SUCCESS" "IP6GRE tunnel created: $name (IPv4: $ipv4_addr)"
    return 0
}

# Create VTI Tunnel
create_vti_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    local key=${4:-100}
    local mtu=${5:-1400}

    log "INFO" "Creating VTI tunnel: $name"

    # Create tunnel
    if ! ip link add ${name} type vti local $local_ip remote $remote_ip key $key; then
        log "ERROR" "Failed to create VTI tunnel: $name"
        return 1
    fi

    # Configure tunnel
    ip link set ${name} up
    ip link set dev ${name} mtu $mtu
    local ipv4_addr=$(generate_random_ipv4)
    ip addr add ${ipv4_addr}/24 dev ${name}

    # Save configuration
    mkdir -p "${TUNNEL_CONFIG_DIR}/${name}"
    cat > "${TUNNEL_CONFIG_DIR}/${name}/config" <<EOF
TYPE=vti
LOCAL_IP=$local_ip
REMOTE_IP=$remote_ip
IPv4_ADDR=$ipv4_addr
KEY=$key
MTU=$mtu
EOF

    log "SUCCESS" "VTI tunnel created: $name (IPv4: $ipv4_addr)"
    return 0
}
