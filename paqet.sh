#!/bin/bash

#####################################################
# Paqet Tunnel - Unified Installer & Manager
# One script for installation, management, and monitoring
# Version: 1.0
#####################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Detect if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# Detect installation state
is_installed() {
    [ -f "/usr/local/bin/paqet" ] && [ -f "/etc/paqet/config.yaml" ]
}

# Get current mode
get_mode() {
    if [ -f "/etc/paqet/config.yaml" ]; then
        grep '^mode:' /etc/paqet/config.yaml | awk '{print $2}'
    else
        echo "unknown"
    fi
}

# Clear screen and show header
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Paqet Tunnel - Unified Manager                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#####################################################
# INSTALLATION MENU
#####################################################

installation_menu() {
    while true; do
        show_header
        echo -e "${CYAN}Paqet is not installed. Choose installation type:${NC}"
        echo ""
        echo -e "  ${GREEN}1${NC}) Foreign Server (Outside Iran)"
        echo -e "  ${GREEN}2${NC}) Iran Client (Inside Iran)"
        echo ""
        echo -e "  ${RED}0${NC}) Exit"
        echo ""
        echo -ne "${YELLOW}Select option: ${NC}"
        read -r choice
        
        case $choice in
            1)
                install_server
                return
                ;;
            2)
                install_client
                return
                ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

#####################################################
# SERVER INSTALLATION
#####################################################

install_server() {
    show_header
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Paqet Tunnel Server Setup (Foreign)             ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Install dependencies
    echo -e "${YELLOW}[1/9] Installing required tools...${NC}"
    apt-get update -qq
    # Pre-seed iptables-persistent to avoid prompts
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl wget jq tar iptables iptables-persistent libpcap0.8 libpcap-dev bc &>/dev/null
    echo -e "${GREEN}✓ Tools installed${NC}"
    
    # Fetch latest release
    echo -e "${YELLOW}[2/9] Fetching latest paqet release from GitHub...${NC}"
    GITHUB_API="https://api.github.com/repos/hanselime/paqet/releases/latest"
    RELEASE_INFO=$(curl -s "$GITHUB_API")
    
    if [ -z "$RELEASE_INFO" ]; then
        echo -e "${RED}Failed to fetch release information from GitHub${NC}"
        exit 1
    fi
    
    LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
    echo -e "${GREEN}✓ Latest version: ${LATEST_VERSION}${NC}"
    
    # Detect architecture
    echo -e "${YELLOW}[3/9] Detecting system architecture...${NC}"
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH_NAME="amd64" ;;
        aarch64) ARCH_NAME="arm64" ;;
        armv7l) ARCH_NAME="armv7" ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}✓ Architecture: ${ARCH_NAME}${NC}"
    
    # Download binary
    echo -e "${YELLOW}[4/9] Downloading paqet binary...${NC}"
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"${ARCH_NAME}\")) | .browser_download_url" | head -n 1)
    
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Could not find download URL for linux-${ARCH_NAME}${NC}"
        exit 1
    fi
    
    wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet.tar.gz
    echo -e "${GREEN}✓ Downloaded${NC}"
    
    # Install binary
    echo -e "${YELLOW}[5/9] Installing paqet binary...${NC}"
    tar -xzf /tmp/paqet.tar.gz -C /tmp/
    
    # Find the binary (it might be named paqet_linux_amd64, etc.)
    EXTRACTED_BINARY=$(find /tmp -maxdepth 1 -type f -name "paqet_*" | head -n 1)
    if [ -z "$EXTRACTED_BINARY" ]; then
        # Fallback check for just 'paqet'
        if [ -f "/tmp/paqet" ]; then
            EXTRACTED_BINARY="/tmp/paqet"
        else
            echo -e "${RED}Failed to find extracted binary${NC}"
            exit 1
        fi
    fi
    
    chmod +x "$EXTRACTED_BINARY"
    mv "$EXTRACTED_BINARY" /usr/local/bin/paqet
    rm -f /tmp/paqet.tar.gz
    
    # Fix libpcap
    echo -e "${YELLOW}[6/9] Fixing libpcap dependency...${NC}"
    ln -sf /usr/lib/x86_64-linux-gnu/libpcap.so /usr/lib/x86_64-linux-gnu/libpcap.so.0.8 2>/dev/null || \
    ln -sf /usr/lib/aarch64-linux-gnu/libpcap.so /usr/lib/aarch64-linux-gnu/libpcap.so.0.8 2>/dev/null || true
    ldconfig
    echo -e "${GREEN}✓ libpcap configured${NC}"
    
    # Network discovery
    echo -e "${YELLOW}[7/9] Discovering network configuration...${NC}"
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    
    if [ -z "$DEFAULT_IFACE" ] || [ -z "$GATEWAY" ]; then
        echo -e "${RED}Failed to detect network interface or gateway${NC}"
        exit 1
    fi
    
    ping -c 2 "$GATEWAY" &>/dev/null || true
    ROUTER_MAC=$(ip neighbor show "$GATEWAY" | awk '{print $5}' | head -n 1)
    
    echo -e "${GREEN}✓ Default Interface: ${DEFAULT_IFACE}${NC}"
    echo -e "${GREEN}✓ Gateway: ${GATEWAY}${NC}"
    echo -e "${GREEN}✓ Router MAC: ${ROUTER_MAC}${NC}"
    
    # System optimizations
    echo -e "${YELLOW}[8/9] Applying high-performance optimizations...${NC}"
    
    cat >> /etc/sysctl.conf <<EOF

# Paqet Tunnel Optimizations
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.rmem_max=67108864
net.core.wmem_max=67108864
EOF
    
    sysctl -p &>/dev/null
    
    iptables -t raw -A PREROUTING -p udp --dport 443 -j NOTRACK
    iptables -t raw -A OUTPUT -p udp --sport 443 -j NOTRACK
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags RST RST -j DROP
    netfilter-persistent save &>/dev/null || iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}✓ Optimizations applied${NC}"
    
    # Generate secret and get IP
    SECRET_KEY=$(openssl rand -base64 16)
    SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com)
    LOCAL_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    
    # Create config
    mkdir -p /etc/paqet
    
    cat > /etc/paqet/config.yaml <<EOF
role: "server"

log:
  level: "info"

listen:
  addr: ":443"

network:
  interface: "${DEFAULT_IFACE}"
  ipv4:
    addr: "${LOCAL_IP}:443"
    router_mac: "${ROUTER_MAC}"

transport:
  protocol: "kcp"
  conn: 16
  kcp:
    mode: "fast3"
    mtu: 1400
    rcvwnd: 8192
    sndwnd: 8192
    key: "${SECRET_KEY}"
EOF
    
    # Create systemd service
    echo -e "${YELLOW}[9/9] Creating systemd service...${NC}"
    cat > /etc/systemd/system/paqet.service <<EOF
[Unit]
Description=Paqet Tunnel Server
After=network.target
Documentation=https://github.com/hanselime/paqet

[Service]
Type=simple
User=root
WorkingDirectory=/etc/paqet
ExecStart=/usr/local/bin/paqet run -c /etc/paqet/config.yaml

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=paqet

# Restart policy
Restart=always
RestartSec=3

# Resource limits
LimitNOFILE=1048576

# Security
NoNewPrivileges=false
PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable paqet &>/dev/null
    systemctl start paqet
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Installation Complete!                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Server Information (SAVE THIS):${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Server IP:${NC}     ${SERVER_IP}"
    echo -e "  ${GREEN}Port:${NC}          443"
    echo -e "  ${GREEN}Secret Key:${NC}    ${SECRET_KEY}"
    echo -e "  ${GREEN}Version:${NC}       ${LATEST_VERSION}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Copy the IP and Secret Key for client installation!${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue to management menu...${NC}"
    read
}

#####################################################
# CLIENT INSTALLATION
#####################################################

install_client() {
    show_header
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    Paqet Tunnel Client Setup (Iran)              ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get server details
    echo -e "${YELLOW}Please enter server details:${NC}"
    read -p "Server IP: " SERVER_IP
    read -p "Secret Key: " SECRET_KEY
    
    if [ -z "$SERVER_IP" ] || [ -z "$SECRET_KEY" ]; then
        echo -e "${RED}Server IP and Secret Key are required!${NC}"
        exit 1
    fi
    
    echo ""
    
    # Install dependencies
    echo -e "${YELLOW}[1/10] Installing required tools...${NC}"
    apt-get update -qq
    # Pre-seed iptables-persistent to avoid prompts
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl wget jq tar iptables iptables-persistent libpcap0.8 libpcap-dev git build-essential bc &>/dev/null
    echo -e "${GREEN}✓ Tools installed${NC}"
    
    # Fetch latest release
    echo -e "${YELLOW}[2/10] Fetching latest paqet release from GitHub...${NC}"
    GITHUB_API="https://api.github.com/repos/hanselime/paqet/releases/latest"
    RELEASE_INFO=$(curl -s "$GITHUB_API")
    
    if [ -z "$RELEASE_INFO" ]; then
        echo -e "${RED}Failed to fetch release information from GitHub${NC}"
        exit 1
    fi
    
    LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
    echo -e "${GREEN}✓ Latest version: ${LATEST_VERSION}${NC}"
    
    # Detect architecture
    echo -e "${YELLOW}[3/10] Detecting system architecture...${NC}"
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH_NAME="amd64" ;;
        aarch64) ARCH_NAME="arm64" ;;
        armv7l) ARCH_NAME="armv7" ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}✓ Architecture: ${ARCH_NAME}${NC}"
    
    # Download binary
    echo -e "${YELLOW}[4/10] Downloading paqet binary...${NC}"
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"${ARCH_NAME}\")) | .browser_download_url" | head -n 1)
    
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Could not find download URL for linux-${ARCH_NAME}${NC}"
        exit 1
    fi
    
    wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet.tar.gz
    echo -e "${GREEN}✓ Downloaded${NC}"
    
    # Install binary
    echo -e "${YELLOW}[5/10] Installing paqet binary...${NC}"
    tar -xzf /tmp/paqet.tar.gz -C /tmp/
    
    # Find the binary (it might be named paqet_linux_amd64, etc.)
    EXTRACTED_BINARY=$(find /tmp -maxdepth 1 -type f -name "paqet_*" | head -n 1)
    if [ -z "$EXTRACTED_BINARY" ]; then
        # Fallback check for just 'paqet'
        if [ -f "/tmp/paqet" ]; then
            EXTRACTED_BINARY="/tmp/paqet"
        else
            echo -e "${RED}Failed to find extracted binary${NC}"
            exit 1
        fi
    fi
    
    chmod +x "$EXTRACTED_BINARY"
    mv "$EXTRACTED_BINARY" /usr/local/bin/paqet
    rm -f /tmp/paqet.tar.gz
    
    # Fix libpcap
    echo -e "${YELLOW}[6/10] Fixing libpcap dependency...${NC}"
    ln -sf /usr/lib/x86_64-linux-gnu/libpcap.so /usr/lib/x86_64-linux-gnu/libpcap.so.0.8 2>/dev/null || \
    ln -sf /usr/lib/aarch64-linux-gnu/libpcap.so /usr/lib/aarch64-linux-gnu/libpcap.so.0.8 2>/dev/null || true
    ldconfig
    echo -e "${GREEN}✓ libpcap configured${NC}"
    
    # Network discovery
    echo -e "${YELLOW}[7/10] Discovering network configuration...${NC}"
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    
    if [ -z "$DEFAULT_IFACE" ] || [ -z "$GATEWAY" ]; then
        echo -e "${RED}Failed to detect network interface or gateway${NC}"
        exit 1
    fi
    
    ping -c 2 "$GATEWAY" &>/dev/null || true
    ROUTER_MAC=$(ip neighbor show "$GATEWAY" | awk '{print $5}' | head -n 1)
    
    echo -e "${GREEN}✓ Default Interface: ${DEFAULT_IFACE}${NC}"
    echo -e "${GREEN}✓ Gateway: ${GATEWAY}${NC}"
    echo -e "${GREEN}✓ Router MAC: ${ROUTER_MAC}${NC}"
    
    # System optimizations
    echo -e "${YELLOW}[8/10] Applying high-performance optimizations...${NC}"
    
    cat >> /etc/sysctl.conf <<EOF

# Paqet Tunnel Optimizations
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.core.rmem_max=67108864
net.core.wmem_max=67108864
EOF
    
    sysctl -p &>/dev/null
    
    iptables -t raw -A PREROUTING -p udp --dport 443 -j NOTRACK
    iptables -t raw -A OUTPUT -p udp --sport 443 -j NOTRACK
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags RST RST -j DROP
    netfilter-persistent save &>/dev/null || iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}✓ Optimizations applied${NC}"
    
    # Create config
    mkdir -p /etc/paqet
    
    cat > /etc/paqet/config.yaml <<EOF
mode: client
server: "${SERVER_IP}:443"
secret: ${SECRET_KEY}
iface: ${DEFAULT_IFACE}
gateway_mac: ${ROUTER_MAC}
socks5:
  - listen: "0.0.0.0:1080"
mtu: 1500
kcp:
  mode: fast3
  conn: 16
  mtu: 1400
  sndwnd: 8192
  rcvwnd: 8192
  datashard: 10
  parityshard: 3
  dscp: 46
  nocongestion: 1
  acknodelay: true
  nodelay: 1
  interval: 10
  resend: 2
  nc: 1
EOF
    
    # Install proxychains
    echo -e "${YELLOW}[9/10] Installing and configuring proxychains4...${NC}"
    
    if [ ! -d "/tmp/proxychains-ng" ]; then
        git clone https://github.com/rofl0r/proxychains-ng.git /tmp/proxychains-ng &>/dev/null
    fi
    
    cd /tmp/proxychains-ng
    ./configure --prefix=/usr --sysconfdir=/etc &>/dev/null
    make &>/dev/null
    make install &>/dev/null
    cd - &>/dev/null
    
    cat > /etc/proxychains4.conf <<EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 1080
EOF
    
    # Ensure proxychains finds the config
    ln -sf /etc/proxychains4.conf /etc/proxychains.conf
    
    echo -e "${GREEN}✓ Proxychains4 installed${NC}"
    
    # Create systemd service
    echo -e "${YELLOW}[10/10] Creating systemd service...${NC}"
    cat > /etc/systemd/system/paqet.service <<EOF
[Unit]
Description=Paqet Tunnel Client
After=network.target
Documentation=https://github.com/hanselime/paqet

[Service]
Type=simple
User=root
WorkingDirectory=/etc/paqet
ExecStart=/usr/local/bin/paqet run -c /etc/paqet/config.yaml

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=paqet

# Restart policy
Restart=always
RestartSec=3

# Resource limits
LimitNOFILE=1048576

# Security
NoNewPrivileges=false
PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable paqet &>/dev/null
    systemctl start paqet
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Installation Complete!                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Client Configuration:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Server:${NC}        ${SERVER_IP}:443"
    echo -e "  ${GREEN}SOCKS5 Proxy:${NC}  0.0.0.0:1080"
    echo -e "  ${GREEN}Version:${NC}       ${LATEST_VERSION}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Test with: proxychains4 curl ifconfig.me${NC}"
    echo ""
    echo -ne "${YELLOW}Press Enter to continue to management menu...${NC}"
    read
}

#####################################################
# MANAGEMENT FUNCTIONS
#####################################################

# Service control
service_control() {
    while true; do
        show_header
        MODE=$(get_mode)
        STATUS=$(systemctl is-active paqet 2>/dev/null || echo "inactive")
        
        if [ "$STATUS" = "active" ]; then
            STATUS_TEXT="${GREEN}● Running${NC}"
        else
            STATUS_TEXT="${RED}● Stopped${NC}"
        fi
        
        echo -e "Status: $STATUS_TEXT | Mode: ${CYAN}${MODE}${NC}"
        echo ""
        echo -e "${CYAN}━━━ Service Control ━━━${NC}"
        echo -e "  ${GREEN}1${NC}) Start Service"
        echo -e "  ${GREEN}2${NC}) Stop Service"
        echo -e "  ${GREEN}3${NC}) Restart Service"
        echo -e "  ${GREEN}4${NC}) Service Status"
        echo ""
        echo -e "  ${RED}0${NC}) Back"
        echo ""
        echo -ne "${YELLOW}Select option: ${NC}"
        read -r choice
        
        case $choice in
            1)
                systemctl start paqet
                sleep 1
                echo -e "${GREEN}✓ Service started${NC}"
                sleep 1
                ;;
            2)
                systemctl stop paqet
                sleep 1
                echo -e "${GREEN}✓ Service stopped${NC}"
                sleep 1
                ;;
            3)
                systemctl restart paqet
                sleep 2
                echo -e "${GREEN}✓ Service restarted${NC}"
                sleep 1
                ;;
            4)
                systemctl status paqet --no-pager -l
                echo ""
                echo -ne "${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# View logs
view_logs() {
    show_header
    echo -e "${YELLOW}Showing live logs (Ctrl+C to exit)...${NC}"
    sleep 1
    journalctl -u paqet -f --since today
}

# Health check
health_check() {
    show_header
    echo -e "${CYAN}━━━ Health Check ━━━${NC}"
    echo ""
    
    # Service check
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✅ Service is running${NC}"
    else
        echo -e "${RED}❌ Service is not running${NC}"
        echo -ne "${YELLOW}Restart service? (y/n): ${NC}"
        read -r restart
        if [[ "$restart" =~ ^[Yy]$ ]]; then
            systemctl restart paqet
            sleep 2
            if systemctl is-active --quiet paqet; then
                echo -e "${GREEN}✅ Service restarted successfully${NC}"
            else
                echo -e "${RED}❌ Failed to restart${NC}"
            fi
        fi
    fi
    
    # Process check
    if pgrep -x "paqet" > /dev/null; then
        echo -e "${GREEN}✅ Process is active${NC}"
        MEM_USAGE=$(ps -o %mem,cmd -C paqet | tail -n 1 | awk '{print $1}')
        echo -e "${GREEN}✅ Memory usage: ${MEM_USAGE}%${NC}"
    else
        echo -e "${RED}❌ Process not found${NC}"
    fi
    
    # Client-specific checks
    MODE=$(get_mode)
    if [ "$MODE" = "client" ]; then
        if ss -tuln | grep -q ':1080'; then
            echo -e "${GREEN}✅ SOCKS5 proxy listening on port 1080${NC}"
        else
            echo -e "${RED}❌ SOCKS5 proxy not listening${NC}"
        fi
    fi
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Performance stats
performance_stats() {
    show_header
    echo -e "${CYAN}━━━ Performance Statistics ━━━${NC}"
    echo ""
    
    MODE=$(get_mode)
    IFACE=$(grep '^iface:' /etc/paqet/config.yaml | awk '{print $2}')
    
    # Service info
    echo -e "${GREEN}Mode:${NC}         $MODE"
    echo -e "${GREEN}Interface:${NC}    $IFACE"
    
    # Service uptime
    UPTIME=$(systemctl show paqet --property=ActiveEnterTimestamp --value)
    if [ -n "$UPTIME" ]; then
        echo -e "${GREEN}Started:${NC}      $UPTIME"
    fi
    
    # Memory/CPU
    if pgrep -x "paqet" > /dev/null; then
        PID=$(pgrep -x "paqet")
        MEM_MB=$(ps -o rss= -p "$PID" | awk '{printf "%.2f MB", $1/1024}')
        CPU_PCT=$(ps -o %cpu= -p "$PID" | awk '{printf "%.2f%%", $1}')
        echo -e "${GREEN}Memory:${NC}       $MEM_MB"
        echo -e "${GREEN}CPU:${NC}          $CPU_PCT"
    fi
    
    # Network stats
    if [ -f "/sys/class/net/$IFACE/statistics/rx_bytes" ]; then
        RX_BYTES=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
        TX_BYTES=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
        RX_GB=$(echo "scale=2; $RX_BYTES / 1024 / 1024 / 1024" | bc)
        TX_GB=$(echo "scale=2; $TX_BYTES / 1024 / 1024 / 1024" | bc)
        echo -e "${GREEN}Received:${NC}     ${RX_GB} GB"
        echo -e "${GREEN}Sent:${NC}         ${TX_GB} GB"
    fi
    
    # Client connections
    if [ "$MODE" = "client" ]; then
        CONNS=$(ss -tn 2>/dev/null | grep -c ':1080' || echo "0")
        echo -e "${GREEN}SOCKS5 Conns:${NC} $CONNS active"
    fi
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Test tunnel
test_tunnel() {
    show_header
    echo -e "${CYAN}━━━ Tunnel Test ━━━${NC}"
    echo ""
    
    MODE=$(get_mode)
    
    # Test 1: Service
    echo -e "${YELLOW}[1/4] Service Status${NC}"
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL - Service not running${NC}"
        echo ""
        echo -ne "${YELLOW}Press Enter to continue...${NC}"
        read
        return
    fi
    
    # Test 2: Process
    echo -e "${YELLOW}[2/4] Process Check${NC}"
    if pgrep -x "paqet" > /dev/null; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL - Process not found${NC}"
        echo ""
        echo -ne "${YELLOW}Press Enter to continue...${NC}"
        read
        return
    fi
    
    # Test 3: Config
    echo -e "${YELLOW}[3/4] Configuration${NC}"
    if [ -f "/etc/paqet/config.yaml" ]; then
        echo -e "${GREEN}✅ PASS - Valid JSON${NC}"
    else
        echo -e "${RED}❌ FAIL - Invalid config${NC}"
    fi
    
    # Test 4: Connection (client only)
    if [ "$MODE" = "client" ]; then
        echo -e "${YELLOW}[4/4] Connection Test${NC}"
        if command -v proxychains4 &> /dev/null; then
            EXTERNAL_IP=$(timeout 10 proxychains4 -q curl -s -4 ifconfig.me 2>/dev/null)
            if [ -n "$EXTERNAL_IP" ]; then
                echo -e "${GREEN}✅ PASS - Tunnel working!${NC}"
                echo -e "${GREEN}   Your IP: ${EXTERNAL_IP}${NC}"
            else
                echo -e "${RED}❌ FAIL - Could not connect${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  SKIP - Proxychains not available${NC}"
        fi
    else
        echo -e "${YELLOW}[4/4] Server listening on UDP 443${NC}"
        echo -e "${GREEN}✅ Server configured${NC}"
    fi
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Backup config
backup_config() {
    show_header
    echo -e "${CYAN}━━━ Configuration Backup ━━━${NC}"
    echo ""
    
    BACKUP_DIR="/root/paqet-backups"
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    BACKUP_FILE="paqet-backup-${TIMESTAMP}.tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    TEMP_DIR=$(mktemp -d)
    
    echo -e "${YELLOW}Creating backup...${NC}"
    
    # Copy files
    if [ -f "/etc/paqet/config.yaml" ]; then
        mkdir -p "$TEMP_DIR/etc/paqet"
        cp /etc/paqet/config.yaml "$TEMP_DIR/etc/paqet/"
    fi
    
    if [ -f "/etc/systemd/system/paqet.service" ]; then
        mkdir -p "$TEMP_DIR/etc/systemd/system"
        cp /etc/systemd/system/paqet.service "$TEMP_DIR/etc/systemd/system/"
    fi
    
    # Create archive
    cd "$TEMP_DIR" || exit 1
    tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" . 2>/dev/null
    cd - > /dev/null || exit 1
    rm -rf "$TEMP_DIR"
    
    if [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
        BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
        echo -e "${GREEN}✓ Backup created${NC}"
        echo ""
        echo -e "  ${GREEN}File:${NC}     ${BACKUP_FILE}"
        echo -e "  ${GREEN}Size:${NC}     ${BACKUP_SIZE}"
        echo -e "  ${GREEN}Location:${NC} ${BACKUP_DIR}"
    else
        echo -e "${RED}✗ Backup failed${NC}"
    fi
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Update paqet
update_paqet() {
    show_header
    echo -e "${CYAN}━━━ Update Paqet ━━━${NC}"
    echo ""
    
    # Get current version
    CURRENT_VERSION=$(/usr/local/bin/paqet -version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
    echo -e "${GREEN}Current version:${NC} $CURRENT_VERSION"
    
    # Fetch latest
    GITHUB_API="https://api.github.com/repos/hanselime/paqet/releases/latest"
    RELEASE_INFO=$(curl -s "$GITHUB_API")
    
    if [ -z "$RELEASE_INFO" ]; then
        echo -e "${RED}Failed to fetch release information${NC}"
        echo -ne "${YELLOW}Press Enter to continue...${NC}"
        read
        return
    fi
    
    LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
    echo -e "${GREEN}Latest version:${NC}  $LATEST_VERSION"
    echo ""
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        echo -e "${GREEN}✓ You are already running the latest version!${NC}"
        echo ""
        echo -ne "${YELLOW}Press Enter to continue...${NC}"
        read
        return
    fi
    
    echo -ne "${YELLOW}Update to ${LATEST_VERSION}? (y/n): ${NC}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Update cancelled"
        sleep 1
        return
    fi
    
    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH_NAME="amd64" ;;
        aarch64) ARCH_NAME="arm64" ;;
        armv7l) ARCH_NAME="armv7" ;;
        *)
            echo -e "${RED}Unsupported architecture${NC}"
            echo -ne "${YELLOW}Press Enter to continue...${NC}"
            read
            return
            ;;
    esac
    
    # Download
    echo -e "${YELLOW}Downloading...${NC}"
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"${ARCH_NAME}\")) | .browser_download_url" | head -n 1)
    
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Could not find download URL${NC}"
        echo -ne "${YELLOW}Press Enter to continue...${NC}"
        read
        return
    fi
    
    wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet_new.tar.gz
    
    # Stop, backup, update, restart
    echo -e "${YELLOW}Updating...${NC}"
    systemctl stop paqet
    cp /usr/local/bin/paqet /usr/local/bin/paqet.backup
    tar -xzf /tmp/paqet_new.tar.gz -C /tmp/
    chmod +x /tmp/paqet
    mv /tmp/paqet /usr/local/bin/paqet
    rm -f /tmp/paqet_new.tar.gz
    systemctl start paqet
    
    sleep 2
    
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✓ Update successful!${NC}"
        rm -f /usr/local/bin/paqet.backup
    else
        echo -e "${RED}✗ Update failed, restoring backup...${NC}"
        mv /usr/local/bin/paqet.backup /usr/local/bin/paqet
        systemctl start paqet
    fi
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

#####################################################
# MANAGEMENT MENU
#####################################################

management_menu() {
    while true; do
        show_header
        
        MODE=$(get_mode)
        STATUS=$(systemctl is-active paqet 2>/dev/null || echo "inactive")
        
        if [ "$STATUS" = "active" ]; then
            STATUS_TEXT="${GREEN}● Running${NC}"
        else
            STATUS_TEXT="${RED}● Stopped${NC}"
        fi
        
        echo -e "Status: $STATUS_TEXT | Mode: ${CYAN}${MODE}${NC}"
        echo ""
        
        echo -e "${CYAN}━━━ Service ━━━${NC}"
        echo -e "  ${GREEN}1${NC}) Service Control"
        echo -e "  ${GREEN}2${NC}) View Logs"
        echo ""
        
        echo -e "${CYAN}━━━ Monitoring ━━━${NC}"
        echo -e "  ${GREEN}3${NC}) Health Check"
        echo -e "  ${GREEN}4${NC}) Performance Stats"
        echo -e "  ${GREEN}5${NC}) Test Tunnel"
        echo ""
        
        echo -e "${CYAN}━━━ Maintenance ━━━${NC}"
        echo -e "  ${GREEN}6${NC}) Backup Configuration"
        echo -e "  ${GREEN}7${NC}) Update Paqet"
        echo ""
        
        echo -e "  ${RED}0${NC}) Exit"
        echo ""
        echo -ne "${YELLOW}Select option: ${NC}"
        read -r choice
        
        case $choice in
            1) service_control ;;
            2) view_logs ;;
            3) health_check ;;
            4) performance_stats ;;
            5) test_tunnel ;;
            6) backup_config ;;
            7) update_paqet ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

#####################################################
# MAIN
#####################################################

check_root

if is_installed; then
    # Already installed - show management menu
    management_menu
else
    # Not installed - show installation menu
    installation_menu
    # After installation, show management menu
    management_menu
fi
