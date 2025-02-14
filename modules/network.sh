#!/bin/bash

# تنظیمات رنگ ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# تابع آماده‌سازی سیستم برای تانل SIT
prepare_sit_tunnel() {
    echo "در حال آماده‌سازی سیستم..."
    
    # حذف و بارگذاری مجدد ماژول sit
    modprobe -r sit
    sleep 1
    modprobe sit
    sleep 1

    # بهینه سازی سیستم
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    sysctl -w net.ipv6.conf.all.accept_ra=0
    sysctl -w net.ipv6.conf.all.autoconf=0
    
    # ریست کردن اینترفیس sit0
    ip link set sit0 down 2>/dev/null
    ip tunnel del sit0 2>/dev/null
    sleep 1
}

# تابع تولید آدرس IPv6 تصادفی
generate_random_ipv6() {
    printf "fde8:b030:%x::%x" $((RANDOM % 65535)) $((RANDOM % 65535))
}

# تابع تولید آدرس IPv4 تصادفی
generate_random_ipv4() {
    local prefix=${1:-"192.168"}
    printf "${prefix}.%d.%d" $((RANDOM % 254 + 1)) $((RANDOM % 254 + 1))
}

# تابع اعتبارسنجی آدرس IP
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

# تابع پیکربندی مسیریابی IPv6
configure_ipv6_routing() {
    local tunnel_name=$1
    local local_ipv6=$2
    
    # اضافه کردن مسیرها
    ip -6 route add ${local_ipv6}/64 dev ${tunnel_name}
    ip -6 route add fde8:b030::/32 dev ${tunnel_name}
    
    # تنظیمات اینترفیس
    sysctl -w net.ipv6.conf.${tunnel_name}.accept_ra=0
    sysctl -w net.ipv6.conf.${tunnel_name}.autoconf=0
    sysctl -w net.ipv6.conf.${tunnel_name}.forwarding=1
}

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

# تابع بررسی وضعیت تانل
check_tunnel_status() {
    local tunnel_name=$1
    
    echo -e "${BLUE}وضعیت تانل ${tunnel_name}:${NC}"
    
    if ip link show ${tunnel_name} >/dev/null 2>&1; then
        local state=$(ip link show ${tunnel_name} | grep -oP 'state \K\w+')
        local mtu=$(ip link show ${tunnel_name} | grep -oP 'mtu \K\d+')
        local ipv6=$(ip -6 addr show dev ${tunnel_name} | grep -oP 'inet6 \K[^/]+')
        
        echo -e "وضعیت: ${GREEN}${state}${NC}"
        echo "MTU: ${mtu}"
        echo "IPv6: ${ipv6}"
        
        if ping6 -c 1 -W 2 ${ipv6} >/dev/null 2>&1; then
            echo -e "پاسخگویی: ${GREEN}بله${NC}"
        else
            echo -e "پاسخگویی: ${RED}خیر${NC}"
        fi
    else
        echo -e "${RED}تانل یافت نشد${NC}"
        return 1
    fi
}

# تابع حذف تانل
delete_tunnel() {
    local tunnel_name=$1
    
    echo "در حال حذف تانل ${tunnel_name}..."
    
    ip link set ${tunnel_name} down 2>/dev/null
    ip tunnel del ${tunnel_name} 2>/dev/null
    rm -rf "/etc/tunnel-manager/${tunnel_name}" 2>/dev/null
    
    if ! ip link show ${tunnel_name} >/dev/null 2>&1; then
        echo -e "${GREEN}تانل با موفقیت حذف شد${NC}"
        return 0
    else
        echo -e "${RED}خطا در حذف تانل${NC}"
        return 1
    fi
}

# تابع نمایش لیست تانل‌ها
list_tunnels() {
    echo -e "${BLUE}تانل‌های فعال:${NC}"
    ip tunnel show
    
    echo -e "\n${BLUE}آدرس‌های IPv6:${NC}"
    ip -6 addr show
}
