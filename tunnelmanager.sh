#!/bin/bash

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source required modules
source "${SCRIPT_DIR}/modules/core.sh"
source "${SCRIPT_DIR}/modules/network.sh"
source "${SCRIPT_DIR}/modules/gost.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create tunnel menu function
create_tunnel_menu() {
    clear
    echo -e "${BLUE}=== Create New Tunnel ===${NC}"
    echo "1) SIT Tunnel (IPv6-in-IPv4)"
    echo "2) GRE Tunnel"
    echo "3) IPIP Tunnel"
    echo "4) Back to main menu"
    
    read -p "Select tunnel type: " tunnel_choice
    
    case $tunnel_choice in
        1) create_sit_tunnel_menu ;;
        2) create_gre_tunnel_menu ;;
        3) create_ipip_tunnel_menu ;;
        4) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}

# Function to create SIT tunnel
create_sit_tunnel_menu() {
    echo -e "${BLUE}Creating SIT Tunnel${NC}"
    read -p "Enter tunnel name: " name
    read -p "Enter local IP: " local_ip
    read -p "Enter remote IP: " remote_ip
    
    create_sit_tunnel "$name" "$local_ip" "$remote_ip"
}

# Function to create GRE tunnel
create_gre_tunnel_menu() {
    echo -e "${BLUE}Creating GRE Tunnel${NC}"
    read -p "Enter tunnel name: " name
    read -p "Enter local IP: " local_ip
    read -p "Enter remote IP: " remote_ip
    
    create_gre_tunnel "$name" "$local_ip" "$remote_ip"
}

# Function to create IPIP tunnel
create_ipip_tunnel_menu() {
    echo -e "${BLUE}Creating IPIP Tunnel${NC}"
    read -p "Enter tunnel name: " name
    read -p "Enter local IP: " local_ip
    read -p "Enter remote IP: " remote_ip
    
    create_ipip_tunnel "$name" "$local_ip" "$remote_ip"
}

# Function to list tunnels
list_tunnels() {
    echo -e "${BLUE}Active Tunnels:${NC}"
    ip tunnel show
    echo -e "\n${BLUE}IPv6 Addresses:${NC}"
    ip -6 addr show
}

# Function to delete tunnel
delete_tunnel() {
    echo -e "${BLUE}Available tunnels:${NC}"
    ip tunnel show
    read -p "Enter tunnel name to delete: " tunnel_name
    
    if [[ -n "$tunnel_name" ]]; then
        ip link set "$tunnel_name" down 2>/dev/null
        ip tunnel del "$tunnel_name" 2>/dev/null
        echo -e "${GREEN}Tunnel $tunnel_name deleted${NC}"
    else
        echo -e "${RED}Invalid tunnel name${NC}"
    fi
}

# Function to test tunnel
test_tunnel() {
    echo -e "${BLUE}Available tunnels:${NC}"
    ip tunnel show
    read -p "Enter tunnel name to test: " tunnel_name
    
    if [[ -n "$tunnel_name" ]]; then
        echo -e "${BLUE}Testing tunnel $tunnel_name...${NC}"
        # Add your testing logic here
        ip link show "$tunnel_name"
        ip addr show "$tunnel_name"
    else
        echo -e "${RED}Invalid tunnel name${NC}"
    fi
}

# Function to show statistics
show_statistics() {
    echo -e "${BLUE}Tunnel Statistics:${NC}"
    for tunnel in $(ip tunnel show | cut -d: -f1); do
        echo -e "\n${YELLOW}Statistics for $tunnel:${NC}"
        ip -s link show "$tunnel"
    done
}

# Function to backup config
backup_config() {
    local backup_dir="/var/backup/tunnels"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/tunnel_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar -czf "$backup_file" -C / etc/tunnel-manager 2>/dev/null
    echo -e "${GREEN}Backup created: $backup_file${NC}"
}

# Show main menu
show_menu() {
    clear
    echo -e "${BLUE}=== Tunnel Management System ===${NC}"
    echo "1) Create New Tunnel"
    echo "2) List Active Tunnels"
    echo "3) Delete Tunnel"
    echo "4) Test Tunnel"
    echo "5) Show Statistics"
    echo "6) Backup Configuration"
    echo "7) Exit"
    echo -e "${BLUE}=============================${NC}"
}

# Main function
main() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi

    while true; do
        show_menu
        read -p "Select an option: " choice

        case $choice in
            1) create_tunnel_menu ;;
            2) list_tunnels ;;
            3) delete_tunnel ;;
            4) test_tunnel ;;
            5) show_statistics ;;
            6) backup_config ;;
            7) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Start the script
main
