#!/bin/bash

###########################################
# Tunnel Manager                         #
# Version: 1.0                           #
###########################################

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source required modules
source "${SCRIPT_DIR}/modules/core.sh"
source "${SCRIPT_DIR}/modules/tunnel.sh"
source "${SCRIPT_DIR}/modules/system.sh"

# Main menu
show_menu() {
    clear
    echo -e "${BLUE}=== Tunnel Management System ===${NC}"
    echo "1) Create SIT Tunnel"
    echo "2) Create GRE Tunnel"
    echo "3) List Active Tunnels"
    echo "4) Test Tunnel Connection"
    echo "5) Delete Tunnel"
    echo "6) Monitor Tunnel"
    echo "7) Optimize System"
    echo "8) Exit"
    echo -e "${BLUE}=============================${NC}"
}

# Main function
main() {
    check_root
    init_system

    while true; do
        show_menu
        read -p "Select option (1-8): " choice
        
        case $choice in
            1)
                read -p "Enter tunnel name: " name
                read -p "Enter local IP: " local_ip
                read -p "Enter remote IP: " remote_ip
                create_sit_tunnel "$name" "$local_ip" "$remote_ip"
                ;;
            2)
                read -p "Enter tunnel name: " name
                read -p "Enter local IP: " local_ip
                read -p "Enter remote IP: " remote_ip
                create_gre_tunnel "$name" "$local_ip" "$remote_ip"
                ;;
            3)
                list_tunnels
                ;;
            4)
                test_tunnel_connection
                ;;
            5)
                delete_tunnel_menu
                ;;
            6)
                monitor_tunnel_menu
                ;;
            7)
                optimize_system
                ;;
            8)
                echo -e "${GREEN}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main
