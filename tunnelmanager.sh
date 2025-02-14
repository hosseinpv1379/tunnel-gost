#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source functions
source "${SCRIPT_DIR}/modules/core.sh"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Show menu
show_menu() {
    clear
    echo -e "${BLUE}=== Tunnel Management System ===${NC}"
    echo "1) Create New Tunnel"
    echo "2) List Active Tunnels"
    echo "3) Delete Tunnel"
    echo "4) Test Tunnel"
    echo "5) Exit"
}

# Main loop
while true; do
    show_menu
    read -p "Select option (1-5): " choice
    
    case $choice in
        1)
            read -p "Enter tunnel name: " name
            read -p "Enter local IP: " local_ip
            read -p "Enter remote IP: " remote_ip
            create_sit_tunnel "$name" "$local_ip" "$remote_ip"
            ;;
        2)
            list_tunnels
            ;;
        3)
            list_tunnels
            read -p "Enter tunnel name to delete: " tunnel_name
            delete_tunnel "$tunnel_name"
            ;;
        4)
            list_tunnels
            read -p "Enter tunnel name to test: " tunnel_name
            test_tunnel "$tunnel_name"
            ;;
        5)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
done
