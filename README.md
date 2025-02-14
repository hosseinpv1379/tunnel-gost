# 🌐 Advanced Tunnel Manager

A professional tunnel management system for Linux, supporting SIT (IPv6-in-IPv4) and GRE (IPv6-over-IPv6) tunnels.

## ✨ Features
- SIT tunnel (IPv6-in-IPv4)
- GRE tunnel (IPv6-over-IPv6) 
- Automatic system optimization
- Systemd service integration
- Persistent across reboots
- Auto IPv6 generation for SIT

## 📋 Requirements
- Linux kernel 3.x or higher
- bash 4.x or higher
- iproute2
- systemd
- root access

## ⚡ Quick Start
```bash
git clone https://github.com/hosseinpv1379/tunnel-gost
cd tunnel-gost
chmod +x tunnel_manager.sh
sudo ./tunnel_manager.sh
