#!/bin/bash

# Main tunnel management script

# Source required modules
source /usr/local/tunnel-manager/modules/core.sh
source /usr/local/tunnel-manager/modules/network.sh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    init_system

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
