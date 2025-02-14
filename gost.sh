#!/bin/bash

# Function to install gost
install_gost() {
   echo "Installing Gost..."
   wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
   gunzip gost-linux-amd64-2.11.5.gz
   mv gost-linux-amd64-2.11.5 /usr/local/bin/gost
   chmod +x /usr/local/bin/gost
}

# Function to create systemd service
create_service() {
   local name=$1
   local command=$2
   
   cat > "/etc/systemd/system/gost-${name}.service" <<EOF
[Unit]
Description=Gost Tunnel Service ($name)
After=network.target

[Service]
Type=simple
ExecStart=$command
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

   systemctl daemon-reload
   systemctl enable "gost-${name}"
   systemctl start "gost-${name}"
}

# Main function
main() {
   # Check if gost is installed
   if ! command -v gost &> /dev/null; then
       install_gost
   fi

   clear
   echo "=== Gost Tunnel Setup ==="
   echo "1) TCP Tunnel"
   echo "2) UDP Tunnel"
   read -p "Select tunnel type (1/2): " tunnel_type

   # Get user input
   read -p "Enter local port: " local_port
   read -p "Enter target IP: " target_ip
   read -p "Enter target port: " target_port

   # Set tunnel protocol
   if [ "$tunnel_type" == "1" ]; then
       protocol="tcp"
   else
       protocol="udp"
   fi

   # Create unique service name
   service_name="${protocol}_${local_port}_${target_port}"

   # Create gost command
   gost_command="/usr/local/bin/gost -L=${protocol}://:${local_port}/${target_ip}:${target_port}"

   # Create and start service
   create_service "$service_name" "$gost_command"

   echo -e "\n=== Tunnel Information ==="
   echo "Protocol: ${protocol}"
   echo "Local Port: ${local_port}"
   echo "Target: ${target_ip}:${target_port}"
   echo "Service Name: gost-${service_name}"
   echo -e "\nUseful Commands:"
   echo "Check Status: systemctl status gost-${service_name}"
   echo "Stop Service: systemctl stop gost-${service_name}"
   echo "Start Service: systemctl start gost-${service_name}"
   echo "Restart Service: systemctl restart gost-${service_name}"
   echo "View Logs: journalctl -u gost-${service_name} -f"
}

# Run the script
main
