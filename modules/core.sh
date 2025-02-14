#!/bin/bash

# تنظیمات رنگ ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# تابع ساخت تانل SIT
create_sit_tunnel() {
    local name=$1
    local local_ip=$2
    local remote_ip=$3
    
    echo "در حال بررسی آدرس‌های IP..."
    if ! validate_ip "$local_ip" "ipv4" || ! validate_ip "$remote_ip" "ipv4"; then
        echo -e "${RED}آدرس IP نامعتبر است${NC}"
        return 1
    }
    
    # آماده‌سازی سیستم
    prepare_sit_tunnel
    
    echo "در حال ساخت تانل..."
    if ! ip tunnel add ${name} mode sit remote ${remote_ip} local ${local_ip} ttl 255; then
        echo -e "${RED}خطا در ساخت تانل${NC}"
        return 1
    fi
    
    # تنظیم تانل
    ip link set ${name} up
    local local_ipv6=$(generate_random_ipv6)
    ip -6 addr add ${local_ipv6}/64 dev ${name}
    ip link set dev ${name} mtu 1400
    
    # پیکربندی مسیریابی
    configure_ipv6_routing "$name" "$local_ipv6"
    
    # ذخیره تنظیمات
    mkdir -p "/etc/tunnel-manager/${name}"
    cat > "/etc/tunnel-manager/${name}/config" <<EOF
TYPE=sit
LOCAL_IP=$local_ip
REMOTE_IP=$remote_ip
LOCAL_IPv6=$local_ipv6
MTU=1400
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    echo -e "${GREEN}تانل با موفقیت ساخته شد${NC}"
    echo -e "نام تانل: ${name}"
    echo -e "IPv6 محلی: ${local_ipv6}"
    echo -e "MTU: 1400"
}

# تابع اصلی برای شروع برنامه
init_system() {
    # بررسی دسترسی root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}این اسکریپت باید با دسترسی root اجرا شود${NC}"
        exit 1
    fi
    
    # ایجاد دایرکتوری‌های مورد نیاز
    mkdir -p /etc/tunnel-manager
    mkdir -p /var/log/tunnel-manager
}

# تابع نمایش منو
show_menu() {
    clear
    echo -e "${BLUE}=== سیستم مدیریت تانل ===${NC}"
    echo "1) ساخت تانل جدید"
    echo "2) نمایش تانل‌های فعال"
    echo "3) حذف تانل"
    echo "4) تست تانل"
    echo "5) نمایش آمار"
    echo "6) پشتیبان‌گیری"
    echo "7) خروج"
    echo -e "${BLUE}=============================${NC}"
}

# بقیه توابع مورد نیاز
prepare_sit_tunnel() {
    echo "در حال آماده‌سازی سیستم..."
    
    modprobe -r sit
    sleep 1
    modprobe sit
    sleep 1
    
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    sleep 1
}

generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

validate_ip() {
    local ip=$1
    local type=$2
    
    case $type in
        "ipv4")
            if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                return 0
            fi
            ;;
        "ipv6")
            if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
                return 0
            fi
            ;;
    esac
    return 1
}

configure_ipv6_routing() {
    local tunnel_name=$1
    local local_ipv6=$2
    
    ip -6 route add ${local_ipv6}/64 dev ${tunnel_name}
    ip -6 route add fde8:b030::/32 dev ${tunnel_name}
    
    sysctl -w net.ipv6.conf.${tunnel_name}.accept_ra=0
    sysctl -w net.ipv6.conf.${tunnel_name}.autoconf=0
    sysctl -w net.ipv6.conf.${tunnel_name}.forwarding=1
}
