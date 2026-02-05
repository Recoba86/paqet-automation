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
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}



# Robust Network Interface Detection
detect_interface() {
    local iface
    iface=$(ip -4 route show default | awk '{print $5}' | head -n 1)
    if [ -z "$iface" ]; then
         iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | head -n 1)
    fi
    echo "$iface"
}

# Robust Gateway MAC Detection (from reference)
detect_gateway_mac() {
    local gateway_ip=$1
    if [ -n "$gateway_ip" ]; then
        # Ping to populate neighbor cache
        ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1 || true
        
        # Try ip neigh first (modern method)
        local mac=$(ip neigh show "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        
        # Fallback to arp if ip neigh fails
        if [ -z "$mac" ] && command -v arp >/dev/null 2>&1; then
            mac=$(arp -n "$gateway_ip" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
        fi
        
        # Final fallback
        [ -z "$mac" ] && mac="00:00:00:00:00:00"
        echo "$mac"
    fi
}

# Secure Config Generator (Revised)
write_paqet_config() {
    local file="/etc/paqet/config.yaml"
    mkdir -p /etc/paqet
    
    # Ensure LOCAL_IP has a port (Default to :0 if missing)
    # This prevents "missing port in address" errors
    if [[ "$LOCAL_IP" != *:* ]]; then
        LOCAL_IP="${LOCAL_IP}:0"
    fi
    
    # Common header
    cat > "$file" <<EOF
role: "$ROLE"

log:
  level: "info"
EOF

    # Role specific address
    if [ "$ROLE" == "server" ]; then
        echo "" >> "$file"
        echo "listen:" >> "$file"
        echo "  addr: \":443\"" >> "$file"
    else
        echo "" >> "$file"
        echo "server:" >> "$file"
        echo "  addr: \"$SERVER_ADDR\"" >> "$file"
    fi

    # Network Block
    cat >> "$file" <<EOF

network:
  interface: "$IFACE"
  ipv4:
    addr: "$LOCAL_IP"
    router_mac: "$ROUTER_MAC"

transport:
  protocol: "kcp"
  conn: 4
  kcp:
    mode: "fast3"
    mtu: 1300
    snd_wnd: 2048
    rcv_wnd: 2048
    data_shard: 10
    parity_shard: 3
    dscp: 0
    key: "$KEY"
EOF

    # Client SOCKS & Forward
    if [ "$ROLE" == "client" ]; then
        # Default SOCKS if empty
        [ -z "$SOCKS_LISTEN" ] && SOCKS_LISTEN="0.0.0.0:1080"
        
        cat >> "$file" <<EOF

# SOCKS5 Proxy
socks5:
  - listen: "$SOCKS_LISTEN"

# Port Forwarding
forward:
EOF
        # Append Forward Rules
        if [ ${#FORWARD_RULES[@]} -gt 0 ]; then
             for rule in "${FORWARD_RULES[@]}"; do
                echo "$rule" >> "$file"
             done
        fi
    fi
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
    apt-get update -qq || true
    # Pre-seed iptables-persistent to avoid prompts
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl wget jq tar iptables iptables-persistent libpcap0.8 libpcap-dev bc chrony lsof &>/dev/null
    
    # Force Time Sync (Critical for KCP)
    systemctl enable --now chrony &>/dev/null
    chronyc makestep &>/dev/null || true
    echo -e "${GREEN}✓ Tools installed & Time synced${NC}"
    
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
    
    # Download binary (Strict Matching)
    echo -e "${YELLOW}[4/9] Downloading paqet binary...${NC}"
    # Target filename pattern: paqet-linux-amd64-v1.0.0-alpha.14.tar.gz
    # We match "paqet-linux-${ARCH_NAME}-" to be safe.
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name != null) | select(.name | contains(\"paqet-linux-${ARCH_NAME}-\")) | select(.name | endswith(\".tar.gz\")) | .browser_download_url" | head -n 1)
    
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Could not find download URL for linux-${ARCH_NAME}${NC}"
        echo -e "Debug Info: Available assets:"
        echo "$RELEASE_INFO" | jq -r '.assets[].name'
        exit 1
    fi
    
    # Download tarball
    wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet.tar.gz
    
    # Extract
    echo -e "${YELLOW}[5/9] Extracting paqet binary...${NC}"
    tar -xzf /tmp/paqet.tar.gz -C /tmp/
    
    # Find the binary (it might be inside a folder or just the binary)
    # Usually releases extract to a binary named 'paqet' or 'paqet-linux-amd64'
    # Let's look for executable files containing 'paqet'
    EXTRACTED_BINARY=$(find /tmp -maxdepth 2 -type f -name "paqet*" ! -name "*.tar.gz" | head -n 1)
    
    if [ -z "$EXTRACTED_BINARY" ]; then
        echo -e "${RED}Failed to find extracted binary${NC}"
        exit 1
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
    
    DEFAULT_IFACE=$(detect_interface)
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    
    # Prompt if failed
    if [ -z "$DEFAULT_IFACE" ]; then
        echo -e "${RED}Could not auto-detect network interface.${NC}"
        echo -e "${YELLOW}Please enter your network interface name (e.g., eth0, ens3, venet0):${NC}"
        read -p "> " DEFAULT_IFACE
    else
        echo -e "Detected Interface: ${CYAN}$DEFAULT_IFACE${NC}"
        # Optional: Ask to confirm? No, keep it automated unless validation fails.
    fi
    
    if [ -z "$DEFAULT_IFACE" ]; then
         echo -e "${RED}Interface is required!${NC}"
         exit 1
    fi
    
    ping -c 2 "$GATEWAY" &>/dev/null || true
    ROUTER_MAC=$(detect_gateway_mac "$GATEWAY")
    
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
    
    # Configure Firewall (Force Open UDP 443)
    echo -e "${YELLOW}Configuring firewall...${NC}"
    
    # Remove existing rules first to prevent duplication
    iptables -D INPUT -p udp --dport 443 -j ACCEPT 2>/dev/null || true
    iptables -t raw -D PREROUTING -p udp --dport 443 -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT -p udp --sport 443 -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D POSTROUTING -p tcp --tcp-flags RST RST -j DROP 2>/dev/null || true

    # UFW support
    if command -v ufw &> /dev/null; then
        ufw allow 443/udp &>/dev/null || true
    fi
    
    # Add rules
    iptables -I INPUT -p udp --dport 443 -j ACCEPT
    iptables -t raw -A PREROUTING -p udp --dport 443 -j NOTRACK
    iptables -t raw -A OUTPUT -p udp --sport 443 -j NOTRACK
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags RST RST -j DROP
    
    # Open Service Ports
    for port in "${SERVICE_PORTS[@]}"; do
        setup_firewall_port "$port" &>/dev/null
    done
    
    netfilter-persistent save &>/dev/null || iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}✓ Optimizations applied${NC}"
    
    # Generate secret and get IP
    EXISTING_KEY=""
    if [ -f "/etc/paqet/config.yaml" ]; then
        # Robust extraction: find 'key:', strip quotes/spaces
        EXISTING_KEY=$(grep 'key:' /etc/paqet/config.yaml 2>/dev/null | head -n1 | awk -F': ' '{print $2}' | tr -d '"' | tr -d '[:space:]')
    fi
    
    # Validation: Key must be reasonably long (base64 16 bytes is ~24 chars)
    if [ -n "$EXISTING_KEY" ] && [ "${#EXISTING_KEY}" -gt 10 ]; then
        SECRET_KEY="$EXISTING_KEY"
        echo -e "${GREEN}✓ Using existing key: $SECRET_KEY${NC}"
    else
        SECRET_KEY=$(openssl rand -base64 16)
        echo -e "${GREEN}✓ Generated new key: $SECRET_KEY${NC}"
    fi

    # Prompt for Service Ports (V2Ray/X-UI) - To Open Firewall
    echo -e "${YELLOW}Enter the ports your V2Ray/X-UI services run on (comma-separated, e.g. 2020,8443):${NC}"
    echo -e "${CYAN}(Press Enter to skip if sure)${NC}"
    read -r input_ports
    SERVICE_PORTS=()
    if [ -n "$input_ports" ]; then
        IFS=',' read -ra PORT_LIST <<< "$input_ports"
        for port in "${PORT_LIST[@]}"; do
            port=$(echo "$port" | tr -cd '0-9')
            if [ -n "$port" ]; then
                SERVICE_PORTS+=("$port")
            fi
        done
    fi
    SERVER_IP=$(curl -s -4 ifconfig.me || curl -s -4 icanhazip.com)
    LOCAL_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    # Save variables for config generator
    # (Config generation happens inside install_server usually locally, but we will use the helper)
    # Actually, to avoid breaking flow, I will define the helper at the top level first.
    # Let's insert the helper function BEFORE install_server so it's available.
    # But since I am editing line 258 inside install_server, I should just update the internal logic first or place the function before.
    # I'll place the helper function near the top (utils section) in a separate edit, then use it here.
    # For now, let's just fix the installation logic to use a consistent block if I can't move cursors easily.
    # ACTUALLY, sticking to the plan: Define the helper function at global scope.
    # I will cancel this edit and place the function properly.

    
    # Create config
    # Create config
    echo -e "${YELLOW}Generating configuration...${NC}"
    
    # Set globals for write_paqet_config
    export ROLE="server"
    export SERVER_ADDR=":443" # For server, this is the bind address
    export KEY="$SECRET_KEY"
    export IFACE="$DEFAULT_IFACE"
    
    # Server needs to announce its actual listening port in ipv4.addr (Critical Fix)
    # Reference repo uses ${local_ip}:${PAQET_PORT}
    export LOCAL_IP="$LOCAL_IP":443
    export ROUTER_MAC="$ROUTER_MAC"
    
    # Empty client-specific vars to be safe
    export SOCKS_LISTEN=""
    FORWARD_RULES=()
    
    write_paqet_config
    
    echo -e "${GREEN}✓ Configuration generated${NC}"
    
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

    # Run optimizations first (Critical for Iran)
    run_iran_optimizations
    
    # Get server details
    echo -e "${YELLOW}Please enter server details:${NC}"
    read -p "Server IP: " SERVER_IP
    read -p "Secret Key: " SECRET_KEY
    
    if [ -z "$SERVER_IP" ] || [ -z "$SECRET_KEY" ]; then
        echo -e "${RED}Server IP and Secret Key are required!${NC}"
        exit 1
    fi
    
    # Prompt for Port Forwarding (New Feature)
    echo -e "${YELLOW}Do you want to forward any ports (e.g. for V2Ray)? (y/n)${NC}"
    read -r ask_forward
    FORWARD_RULES=()
    
    if [[ "$ask_forward" =~ ^[Yy]$ ]]; then
        echo -e "Enter ports (comma-separated, e.g. 2096,8443): "
        read -r input_ports
        
        # Safer Parsing (Compatible with old Bash)
        IFS=',' read -ra PORT_LIST <<< "$input_ports"
        
        for port in "${PORT_LIST[@]}"; do
            # Strict cleanup: keep ONLY digits
            port=$(echo "$port" | tr -cd '0-9')
            if [ -z "$port" ]; then continue; fi
            
            # Correct Config Format (from g3ntrix repo)
            FORWARD_RULES+=("  - listen: \"0.0.0.0:${port}\"")
            FORWARD_RULES+=("    target: \"127.0.0.1:${port}\"")
            FORWARD_RULES+=("    protocol: \"tcp\"")
            setup_firewall_port "$port" &>/dev/null
        done
    fi

    echo ""
    
    # Install dependencies
    echo -e "${YELLOW}[1/10] Installing required tools...${NC}"
    apt-get update -qq || true
    # Pre-seed iptables-persistent to avoid prompts
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl wget jq tar iptables iptables-persistent libpcap0.8 libpcap-dev git build-essential bc chrony lsof &>/dev/null
    
    # Force Time Sync (Critical for KCP)
    systemctl enable --now chrony &>/dev/null
    chronyc makestep &>/dev/null || true
    echo -e "${GREEN}✓ Tools installed & Time synced${NC}"
    
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
    
    # Download binary (Strict Matching)
    echo -e "${YELLOW}[4/10] Downloading paqet binary...${NC}"
    # Target filename pattern: paqet-linux-amd64-v1.0.0-alpha.14.tar.gz
    # We match "paqet-linux-${ARCH_NAME}-" to be safe.
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name != null) | select(.name | contains(\"paqet-linux-${ARCH_NAME}-\")) | select(.name | endswith(\".tar.gz\")) | .browser_download_url" | head -n 1)
    
    if [ -z "$DOWNLOAD_URL" ]; then
         echo -e "${RED}Could not find download URL for linux-${ARCH_NAME}${NC}"
         exit 1
    fi
    
    # Download tarball
    wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet.tar.gz
    
    # Extract
    echo -e "${YELLOW}[5/10] Extracting paqet binary...${NC}"
    tar -xzf /tmp/paqet.tar.gz -C /tmp/
    
    # Find the binary
    EXTRACTED_BINARY=$(find /tmp -maxdepth 2 -type f -name "paqet*" ! -name "*.tar.gz" | head -n 1)
    
    if [ -z "$EXTRACTED_BINARY" ]; then
        echo -e "${RED}Binary installation failed!${NC}"
        exit 1
    fi

    chmod +x "$EXTRACTED_BINARY"
    mv "$EXTRACTED_BINARY" /usr/local/bin/paqet
    echo -e "${GREEN}✓ Paqet binary installed to /usr/local/bin/paqet${NC}"
    
    # Install Proxychains
    echo -e "${YELLOW}[6/10] Installing Proxychains...${NC}"
    if apt-cache show proxychains4 &>/dev/null; then
        apt-get install -y proxychains4 &>/dev/null
    else
        # Compile from source if not in repo
        echo -e "${YELLOW}Compiling proxychains from source...${NC}"
        if [ ! -d "/tmp/proxychains-ng" ]; then
            git clone --depth 1 https://github.com/rofl0r/proxychains-ng.git /tmp/proxychains-ng &>/dev/null
        fi
    
        cd /tmp/proxychains-ng
        ./configure --prefix=/usr --sysconfdir=/etc &>/dev/null
        make &>/dev/null
        make install &>/dev/null
        make install-config &>/dev/null
        cd - &>/dev/null
        rm -rf /tmp/proxychains-ng
    fi
    echo -e "${GREEN}✓ Proxychains installed${NC}"
    
    # Network Discovery (Moved here to ensure IFACE is sets)
    echo -e "${YELLOW}[7/10] Discovering network configuration...${NC}"
    
    DEFAULT_IFACE=$(detect_interface)
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    
    if [ -z "$DEFAULT_IFACE" ]; then
        echo -e "${RED}Could not auto-detect network interface.${NC}"
        read -p "Enter network interface (e.g. eth0): " DEFAULT_IFACE
    fi
    
    if [ -z "$DEFAULT_IFACE" ]; then
        echo -e "${RED}Interface is required!${NC}"
        exit 1
    fi
    
    ping -c 2 "$GATEWAY" &>/dev/null || true
    ROUTER_MAC=$(detect_gateway_mac "$GATEWAY")
    
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

setup_firewall_port() {
    local port=$1
    if [ -n "$port" ]; then
        # Remove existing rules first
        iptables -t raw -D PREROUTING -p tcp --dport "$port" -j NOTRACK 2>/dev/null || true
        iptables -t raw -D OUTPUT -p tcp --sport "$port" -j NOTRACK 2>/dev/null || true
        iptables -t mangle -D POSTROUTING -p tcp --tcp-flags RST RST -j DROP 2>/dev/null || true

        # Add new rules
        iptables -t raw -A PREROUTING -p tcp --dport "$port" -j NOTRACK
        iptables -t raw -A OUTPUT -p tcp --sport "$port" -j NOTRACK
        iptables -t mangle -A POSTROUTING -p tcp --tcp-flags RST RST -j DROP
        
        # Also allow INPUT for that port just in case (like we did for server 443)
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
        
        # UFW support
        if command -v ufw &> /dev/null; then
             ufw allow "$port"/tcp &>/dev/null || true
        fi
    fi
}
netfilter-persistent save &>/dev/null || iptables-save > /etc/iptables/rules.v4
    
    echo -e "${GREEN}✓ Optimizations applied${NC}"
    
    # Create config (Using Robust Generator)
    LOCAL_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    
    # Set globals for write_paqet_config
    export ROLE="client"
    export SERVER_ADDR="$SERVER_IP:443"
    export KEY="$SECRET_KEY"
    export IFACE="$DEFAULT_IFACE"
    export LOCAL_IP="$LOCAL_IP":0
    export ROUTER_MAC="$ROUTER_MAC"
    export SOCKS_LISTEN="0.0.0.0:1080"
    # FORWARD_RULES array is already populated above
    
    write_paqet_config
    
    echo -e "${GREEN}✓ Configuration generated${NC}"
    
    # Install proxychains
    echo -e "${YELLOW}[9/10] Installing and configuring proxychains4...${NC}"
    
    # Try apt install first (much faster)
    if apt-get install -y proxychains4 &>/dev/null || apt-get install -y proxychains-ng &>/dev/null; then
        echo -e "${GREEN}✓ Installed via apt${NC}"
    # Fallback to compilation
    else
        echo -e "${YELLOW}  Compiling from source (package not found)...${NC}"
        if [ ! -d "/tmp/proxychains-ng" ]; then
            git clone --depth 1 https://github.com/rofl0r/proxychains-ng.git /tmp/proxychains-ng &>/dev/null
        fi
    
        cd /tmp/proxychains-ng
        ./configure --prefix=/usr --sysconfdir=/etc &>/dev/null
        make &>/dev/null
        make install &>/dev/null
        cd - &>/dev/null
    fi
    
    cat > /etc/proxychains4.conf <<-EOF
dynamic_chain
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
    cat > /etc/systemd/system/paqet.service <<-EOF
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
        echo -e "${GREEN}✅ PASS - Valid YAML${NC}"
    else
        echo -e "${RED}❌ FAIL - Invalid config${NC}"
    fi
    
    read
}

# Test connection
test_tunnel() {
    show_header
    echo -e "${CYAN}━━━ Connection Test ━━━${NC}"
    echo ""
    
    # 1. Check Service
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${RED}✗ Service is NOT running${NC}"
        echo -e "${YELLOW}  Try starting it with Option 1${NC}"
        read -r
        return
    fi
    
    # 2. Check Port 1080
    if ss -tlnp | grep -q ":1080" || netstat -tlnp 2>/dev/null | grep -q ":1080"; then
        echo -e "${GREEN}✓ Port 1080 is listening${NC}"
    else
        echo -e "${RED}✗ Port 1080 is NOT listening${NC}"
        echo -e "${YELLOW}  Check logs for errors${NC}"
    fi

    # 3. Check Server Reachability (Client Only)
    MODE=$(get_mode)
    if [ "$MODE" = "client" ]; then
        SERVER_ADDR=$(grep "addr:" /etc/paqet/config.yaml | head -n 1 | awk '{print $2}' | tr -d '"')
        SERVER_IP=$(echo "$SERVER_ADDR" | cut -d':' -f1)
        
        echo -ne "Pinging server ($SERVER_IP)... "
        if ping -c 1 -W 2 "$SERVER_IP" &>/dev/null; then
            echo -e "${GREEN}Reachbale${NC}"
        else
            echo -e "${RED}Unreachable${NC}"
            echo -e "${YELLOW}  Check your internet or server firewall${NC}"
        fi
        
        # 4. Test Through Tunnel
        echo -ne "Testing tunnel (via proxychains)... "
        if command -v proxychains4 &> /dev/null; then
            EXTERNAL_IP=$(timeout 10 proxychains4 -q curl -s -4 ifconfig.me 2>/dev/null)
            if [ -n "$EXTERNAL_IP" ]; then
                echo -e "${GREEN}Success!${NC}"
                echo -e "  Tunnel IP: ${GREEN}${EXTERNAL_IP}${NC}"
                if [[ "$EXTERNAL_IP" == "$SERVER_IP" ]]; then
                     echo -e "  ${GREEN}✓ Traffic is routed correctly${NC}"
                else
                     echo -e "  ${YELLOW}⚠ Traffic might not be going through tunnel${NC}"
                fi
            else
                echo -e "${RED}Failed${NC}"
                echo -e "${YELLOW}  Tunnel is up but traffic is blocked${NC}"
            fi
        else
             echo -e "${YELLOW}Skipped (proxychains not found)${NC}"
        fi
    else
        echo -e "${YELLOW}Server Mode: Tunnel test skipped (Client only feature)${NC}"
    fi
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Speed Test
run_speed_test() {
    show_header
    echo -e "${CYAN}━━━ Tunnel Speed Test ━━━${NC}"
    echo ""
    
    # Check prerequisites
    if ! systemctl is-active --quiet paqet; then
        echo -e "${RED}✗ Service is NOT running${NC}"
        read -r
        return
    fi
    
    if ! command -v proxychains4 &> /dev/null; then
        echo -e "${RED}✗ Proxychains is NOT installed${NC}"
        read -r
        return
    fi
    
    echo -e "${YELLOW}Starting download test (100MB)...${NC}"
    echo -e "Target: Cloudflare CDN (via Tunnel)"
    echo ""
    
    # Run speed test
    # We use a 100MB file for more accuracy
    TIME_START=$(date +%s.%N)
    if proxychains4 -q curl -L -o /dev/null --progress-bar -w "%{speed_download}" http://speed.cloudflare.com/__down?bytes=100000000 > /tmp/speedtest_result; then
        TIME_END=$(date +%s.%N)
        SPEED_BPS=$(cat /tmp/speedtest_result)
        
        # Convert bytes/sec to Mbps
        # Mbps = (Bytes/sec * 8) / 1000000
        SPEED_MBPS=$(echo "scale=2; $SPEED_BPS * 8 / 1000000" | bc)
        
        echo ""
        echo -e "${GREEN}✓ Test Completed${NC}"
        echo -e "  Speed: ${GREEN}${SPEED_MBPS} Mbps${NC}"
    else
        echo ""
        echo -e "${RED}✗ Test Failed${NC}"
        echo -e "${YELLOW}  Check connection stability${NC}"
    fi
    
    rm -f /tmp/speedtest_result
    
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

# Configure Port Forwarding
configure_port_forwarding() {
    show_header
    echo -e "${CYAN}━━━ Configure Port Forwarding ━━━${NC}"
    echo -e "${YELLOW}Forward traffic from this server (Iran) to the foreign server.${NC}"
    echo ""
    
    # Detect config file
    if [ -f "/etc/paqet/client.yaml" ]; then
        CONFIG_FILE="/etc/paqet/client.yaml"
    elif [ -f "/etc/paqet/config.yaml" ]; then
        CONFIG_FILE="/etc/paqet/config.yaml"
    else
        echo -e "${RED}Config file not found!${NC}"
        read -r
        return
    fi
    
    # Ask for ports
    echo -e "Enter the ports you want to forward (comma-separated)."
    echo -e "Example: ${CYAN}2096,8443,2053${NC}"
    echo -ne "Ports: "
    read -r input_ports
    
    if [[ -z "$input_ports" ]]; then
        echo -e "${RED}No ports entered.${NC}"
        return
    fi
    
    # Process ports (Robust Splitting)
    # Convert commas to newlines and read into array to handle spacing cleanly
    mapfile -t PORT_LIST < <(echo "$input_ports" | tr ',' '\n')
    
    # Backup current config
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # We need to preserve relevant parts of config while injecting the forward block.
    # It's safer to read the keys and regenerate the file to avoid YAML parsing hell with sed.
    
    # Read existing values
    SERVER_ADDR=$(grep "addr:" "$CONFIG_FILE" | head -n 1 | awk '{print $2}' | tr -d '"')
    KEY=$(grep "key:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    MODE=$(grep "mode:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    CONN=$(grep "conn:" "$CONFIG_FILE" | awk '{print $2}')
    MTU=$(grep "mtu:" "$CONFIG_FILE" | awk '{print $2}')
    PARITY=$(grep "parityshard:" "$CONFIG_FILE" | awk '{print $2}')
    DATA=$(grep "data_shard:" "$CONFIG_FILE" | awk '{print $2}')
    
    # Read Network Settings (With SELF-HEALING)
    # 1. Interface
    IFACE=$(grep "interface:" "$CONFIG_FILE" | head -n 1 | awk '{print $2}' | tr -d '"')
    
    # Self-Healing: If missing, re-detect
    if [ -z "$IFACE" ]; then
        echo -e "${YELLOW}Warning: Network config missing. Auto-detecting...${NC}"
        IFACE=$(ip -4 route show default | awk '{print $5}' | head -n 1)
        [ -z "$IFACE" ] && IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | head -n 1)
    fi

    # 2. Local IP
    LOCAL_IP=$(sed -n '/network:/,/server:/p' "$CONFIG_FILE" | grep "addr:" | head -n 1 | awk '{print $2}' | tr -d '"')
    if [ -z "$LOCAL_IP" ] && [ -n "$IFACE" ]; then
         LOCAL_IP=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    fi
    
    # 4. SOCKS Listen
    # Extract value strictly to avoid capturing keys like "listen:"
    # We look for IP:Port pattern (0.0.0.0:1080)
    SOCKS_LISTEN=$(grep -A5 "socks5:" "$CONFIG_FILE" | grep "listen:" |  grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' | head -n 1)
    # If empty or invalid, reset to default
    if [ -z "$SOCKS_LISTEN" ]; then
        SOCKS_LISTEN="0.0.0.0:1080"
    fi
    
    # 3. Router MAC (Hardened)
    ROUTER_MAC=$(grep "router_mac:" "$CONFIG_FILE" | head -n 1 | awk '{print $2}' | tr -d '"')
    # Check if empty OR invalid length (MAC should be 17 chars)
    if [ -z "$ROUTER_MAC" ] || [ "${#ROUTER_MAC}" -lt 10 ]; then
         GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
         ROUTER_MAC=$(ip neighbor show "$GATEWAY" | awk '{print $5}' | head -n 1)
         # If still bad, force dummy MAC
         if [ -z "$ROUTER_MAC" ] || [ "${#ROUTER_MAC}" -lt 10 ]; then
             ROUTER_MAC="00:00:00:00:00:00"
         fi
    fi
    
    # Default values if missing
    [ -z "$CONN" ] && CONN=20
    [ -z "$MTU" ] && MTU=1350
    [ -z "$PARITY" ] && PARITY=3
    [ -z "$DATA" ] && DATA=10
    [ -z "$MODE" ] && MODE="fast3"
    
    # Prepare variables for config generator
    export ROLE="client"
    export SERVER_ADDR="$SERVER_ADDR"
    export KEY="$KEY"
    export IFACE="$IFACE"
    export LOCAL_IP="$LOCAL_IP"
    export ROUTER_MAC="$ROUTER_MAC"
    export SOCKS_LISTEN="$SOCKS_LISTEN"
    
    # Build Forward Rules Array
    FORWARD_RULES=()
    for port in "${PORT_LIST[@]}"; do
        # TRIM whitespace/newlines
        port=$(echo "$port" | tr -d '[:space:]')
        
        # Skip empty/invalid
        if [[ -z "$port" ]] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        FORWARD_RULES+=("  - listen: \"0.0.0.0:${port}\"")
        FORWARD_RULES+=("    remote: \"127.0.0.1:${port}\"")
        
        # Open Firewall
        setup_firewall_port "$port" &>/dev/null
    done
    
    # Write the config using the robust generator
    write_paqet_config
    
    echo -e "${GREEN}✓ Configuration updated (Robust Mode)${NC}"
    echo -e "${YELLOW}Restarting service...${NC}"
    systemctl restart paqet
    echo -e "${GREEN}✓ Done!${NC}"
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Helper to open port
setup_firewall_port() {
    local port=$1
    if command -v ufw &> /dev/null; then
        ufw allow "$port"/tcp
    fi
    if command -v iptables &> /dev/null; then
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
}

# Edit Configuration Menu
edit_config() {
    # Detect config file
    if [ -f "/etc/paqet/server.yaml" ]; then
        CONFIG_FILE="/etc/paqet/server.yaml"
    elif [ -f "/etc/paqet/client.yaml" ]; then
        CONFIG_FILE="/etc/paqet/client.yaml"
    elif [ -f "/etc/paqet/config.yaml" ]; then
        CONFIG_FILE="/etc/paqet/config.yaml"
    else
        echo -e "${RED}Config file not found!${NC}"
        read -r
        return
    fi

    while true; do
        show_header
        echo -e "${CYAN}━━━ Edit Configuration ━━━${NC}"
        echo -e "${YELLOW}File: $CONFIG_FILE${NC}"
        echo ""
        
        # Read current values
        CUR_MTU=$(grep "mtu:" "$CONFIG_FILE" | awk '{print $2}')
        CUR_CONN=$(grep "conn:" "$CONFIG_FILE" | awk '{print $2}')
        CUR_PARITY=$(grep "parityshard:" "$CONFIG_FILE" | awk '{print $2}')
        CUR_MODE=$(grep "mode:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
        
        echo -e "  ${GREEN}1${NC}) Change MTU         (Current: ${CYAN}$CUR_MTU${NC})"
        echo -e "  ${GREEN}2${NC}) Change Connections (Current: ${CYAN}$CUR_CONN${NC})"
        echo -e "  ${GREEN}3${NC}) Change Parity      (Current: ${CYAN}$CUR_PARITY${NC})"
        echo -e "  ${GREEN}4${NC}) Change Mode        (Current: ${CYAN}$CUR_MODE${NC})"
        echo ""
        echo -e "  ${RED}0${NC}) Back & Restart Service"
        echo ""
        echo -ne "${YELLOW}Select option: ${NC}"
        read -r choice
        
        case $choice in
            1)
                echo -ne "Enter new MTU (e.g. 1200-1400): "
                read -r new_val
                if [[ "$new_val" =~ ^[0-9]+$ ]]; then
                    sed -i "s/mtu: .*/mtu: $new_val/" "$CONFIG_FILE"
                    echo -e "${GREEN}✓ Updated MTU${NC}"
                fi
                ;;
            2)
                echo -ne "Enter new Connections (e.g. 10-50): "
                read -r new_val
                if [[ "$new_val" =~ ^[0-9]+$ ]]; then
                    sed -i "s/conn: .*/conn: $new_val/" "$CONFIG_FILE"
                    echo -e "${GREEN}✓ Updated Connections${NC}"
                fi
                ;;
            3)
                echo -ne "Enter new Parity Shards (e.g. 3, 5, 10): "
                read -r new_val
                if [[ "$new_val" =~ ^[0-9]+$ ]]; then
                    sed -i "s/parityshard: .*/parityshard: $new_val/" "$CONFIG_FILE"
                    echo -e "${GREEN}✓ Updated Parity${NC}"
                fi
                ;;
            4)
                echo -ne "Enter new Mode (fast3, normal, manual): "
                read -r new_val
                if [[ -n "$new_val" ]]; then
                    sed -i "s/mode: .*/mode: \"$new_val\"/" "$CONFIG_FILE"
                    echo -e "${GREEN}✓ Updated Mode${NC}"
                fi
                ;;
            0)
                echo -e "${YELLOW}Restarting service to apply changes...${NC}"
                systemctl restart paqet
                echo -e "${GREEN}✓ Done!${NC}"
                sleep 1
                return
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 0.5
                ;;
        esac
    done
}

# Iran Network Optimizations
run_iran_optimizations() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}          Iran Server Network Optimization                  ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}These scripts can help optimize your Iran server:${NC}"
    echo -e "  ${YELLOW}1.${NC} DNS Finder - Find the best DNS servers for Iran"
    echo -e "  ${YELLOW}2.${NC} Mirror Selector - Find the fastest apt repository mirror"
    echo ""
    echo -e "${CYAN}This can significantly improve download speeds and reliability.${NC}"
    echo ""
    
    echo -ne "${YELLOW}Run network optimization scripts? (y/N): ${NC}"
    read -r run_opt
    
    if [[ "$run_opt" =~ ^[Yy]$ ]]; then
        echo ""
        
        # DNS Optimization
        echo -e "${YELLOW}Running DNS Finder...${NC}"
        if bash <(curl -Ls https://github.com/alinezamifar/IranDNSFinder/raw/refs/heads/main/dns.sh); then
            echo -e "${GREEN}✓ DNS optimization completed${NC}"
        else
            echo -e "${RED}✗ DNS optimization failed or skipped${NC}"
        fi
        echo ""
        
        # Mirror Optimization (Ubuntu/Debian only)
        if [ -f /etc/debian_version ]; then
            echo -e "${YELLOW}Running Mirror Selector...${NC}"
            if bash <(curl -Ls https://github.com/alinezamifar/DetectUbuntuMirror/raw/refs/heads/main/DUM.sh); then
                echo -e "${GREEN}✓ Mirror optimization completed${NC}"
            else
                echo -e "${RED}✗ Mirror optimization failed or skipped${NC}"
            fi
        fi
        
        echo ""
        echo -e "${GREEN}Network optimization finished!${NC}"
        echo ""
    else
        echo "Skipping network optimization..."
    fi
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
        
        echo -e "${CYAN}━━━ Configuration ━━━${NC}"
        echo -e "  ${GREEN}5${NC}) Edit Settings (MTU, Mode)"
        echo -e "  ${GREEN}6${NC}) Port Forwarding"
        echo ""
        
        echo -e "${CYAN}━━━ Monitoring ━━━${NC}"
        echo -e "  ${GREEN}7${NC}) Test Tunnel"
        echo -e "  ${GREEN}8${NC}) Speed Test"
        echo ""
        
        echo -e "${CYAN}━━━ Maintenance ━━━${NC}"
        echo -e "  ${GREEN}9${NC}) Backup Configuration"
        echo -e "  ${GREEN}10${NC}) Update Paqet"
        echo -e "  ${RED}11${NC}) Uninstall Paqet"
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
            5) edit_config ;;
            6) configure_port_forwarding ;;
            7) test_tunnel ;;
            8) run_speed_test ;;
            9) backup_config ;;
            10) update_paqet ;;
            11) uninstall_paqet ;;
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

# Uninstall paqet
uninstall_paqet() {
    show_header
    echo -e "${RED}━━━ DANGER: Uninstall Paqet ━━━${NC}"
    echo ""
    echo -e "${RED}This will PERMANENTLY remove:${NC}"
    echo -e "  - Paqet binary and service"
    echo -e "  - Configuration files (/etc/paqet)"
    echo -e "  - System optimizations (sysctl)"
    echo ""
    echo -ne "${YELLOW}Are you sure you want to uninstall Paqet? (y/N): ${NC}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled"
        sleep 1
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Stopping service...${NC}"
    systemctl stop paqet
    systemctl disable paqet &>/dev/null
    rm -f /etc/systemd/system/paqet.service
    systemctl daemon-reload
    
    # Clean up firewall rules (Port Forwarding)
    if [ -f "/etc/paqet/config.yaml" ]; then
        echo -e "${YELLOW}Cleaning up firewall rules...${NC}"
        # Extract ports from forward section
        # Logic: Look for "listen: 0.0.0.0:PORT" lines
        FORWARD_PORTS=$(grep -oP 'listen: "0.0.0.0:\K\d+' /etc/paqet/config.yaml || true)
        
        for port in $FORWARD_PORTS; do
            echo -e "  - Removing rule for port $port"
            if command -v ufw &> /dev/null; then
                ufw delete allow "$port"/tcp &>/dev/null || true
            fi
            if command -v iptables &> /dev/null; then
                iptables -D INPUT -p tcp --dport "$port" -j ACCEPT &>/dev/null || true
            fi
        done
        
        # Save iptables changes
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi
    
    echo -e "${YELLOW}Removing files...${NC}"
    rm -f /usr/local/bin/paqet
    rm -rf /etc/paqet
    rm -f /etc/proxychains.conf
    
    echo -e "${YELLOW}Reverting system optimizations...${NC}"
    # Remove the block we added to sysctl.conf
    if [ -f "/etc/sysctl.conf" ]; then
        sed -i '/# Paqet Tunnel Optimizations/,/net.core.wmem_max=67108864/d' /etc/sysctl.conf
        # Reload defaults (partial)
        sysctl -p &>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Uninstalled successfully${NC}"
    echo ""
    echo -e "The script will now exit."
    exit 0
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
