#!/bin/bash

# Network module for Tunnel Manager
# Handles network-related functions

# Generate random IPv6 address
generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

# Generate random IPv4 address
generate_random_ipv4() {
    local prefix=${1:-"192.168"}
    printf "${prefix}.%d.%d" $((RANDOM % 254 + 1)) $((RANDOM % 254 + 1))
}

# Validate IP address
validate_ip() {
    local ip=$1
    local type=$2

    case $type in
        "ipv4")
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
            ;;
        "ipv6")
            if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
                return 0
            fi
            return 1
            ;;
    esac
}

# Configure IPv6 routing
configure_ipv6_routing() {
    local tunnel_name=$1
    local local_ipv6=$2
    local remote_ipv6=$3

    # Add routes
    ip -6 route add ${local_ipv6}/64 dev ${tunnel_name}
    ip -6 route add fde8:b030::/32 dev ${tunnel_name}
    ip -6 route add ${remote_ipv6}/128 dev ${tunnel_name}

    # Configure interface
    sysctl -w net.ipv6.conf.${tunnel_name}.accept_ra=0
    sysctl -w net.ipv6.conf.${tunnel_name}.autoconf=0
    sysctl -w net.ipv6.conf.${tunnel_name}.forwarding=1
}

# Test network connectivity
test_connectivity() {
    local target=$1
    local count=${2:-3}
    local timeout=${3:-2}

    if [[ $target =~ ":" ]]; then
        ping6 -c $count -W $timeout $target >/dev/null 2>&1
    else
        ping -c $count -W $timeout $target >/dev/null 2>&1
    fi
    return $?
}
