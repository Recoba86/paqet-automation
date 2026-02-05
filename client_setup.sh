#!/bin/bash

#####################################################
# Paqet Tunnel Client Setup Script (Iran)
# Fully automated installation with dynamic versioning
#####################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Paqet Tunnel Client Automated Setup (Iran)    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Prompt for server details
echo -e "${YELLOW}Please enter server details:${NC}"
read -p "Server IP: " SERVER_IP
read -p "Secret Key: " SECRET_KEY

if [ -z "$SERVER_IP" ] || [ -z "$SECRET_KEY" ]; then
    echo -e "${RED}Server IP and Secret Key are required!${NC}"
    exit 1
fi

# Install required tools
echo -e "${YELLOW}[1/10] Installing required tools...${NC}"
apt-get update -qq
apt-get install -y curl wget jq tar iptables iptables-persistent libpcap0.8 libpcap-dev git build-essential &>/dev/null
echo -e "${GREEN}✓ Tools installed${NC}"

# Fetch latest release info from GitHub
echo -e "${YELLOW}[2/10] Fetching latest paqet release from GitHub...${NC}"
GITHUB_API="https://api.github.com/repos/hanselime/paqet/releases/latest"
RELEASE_INFO=$(curl -s "$GITHUB_API")

if [ -z "$RELEASE_INFO" ]; then
    echo -e "${RED}Failed to fetch release information from GitHub${NC}"
    exit 1
fi

LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
echo -e "${GREEN}✓ Latest version: ${LATEST_VERSION}${NC}"

# Detect system architecture
echo -e "${YELLOW}[3/10] Detecting system architecture...${NC}"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_NAME="amd64"
        ;;
    aarch64)
        ARCH_NAME="arm64"
        ;;
    armv7l)
        ARCH_NAME="armv7"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}✓ Architecture: ${ARCH_NAME}${NC}"

# Find and download the correct asset
echo -e "${YELLOW}[4/10] Downloading paqet binary...${NC}"
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"${ARCH_NAME}\")) | .browser_download_url" | head -n 1)

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Could not find download URL for linux-${ARCH_NAME}${NC}"
    exit 1
fi

wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet.tar.gz
echo -e "${GREEN}✓ Downloaded${NC}"

# Extract and install binary
echo -e "${YELLOW}[5/10] Installing paqet binary...${NC}"
tar -xzf /tmp/paqet.tar.gz -C /tmp/
chmod +x /tmp/paqet
mv /tmp/paqet /usr/local/bin/paqet
rm -f /tmp/paqet.tar.gz

# Fix libpcap dependency
echo -e "${YELLOW}[6/10] Fixing libpcap dependency...${NC}"
ln -sf /usr/lib/x86_64-linux-gnu/libpcap.so /usr/lib/x86_64-linux-gnu/libpcap.so.0.8 2>/dev/null || \
ln -sf /usr/lib/aarch64-linux-gnu/libpcap.so /usr/lib/aarch64-linux-gnu/libpcap.so.0.8 2>/dev/null || \
echo -e "${YELLOW}Note: libpcap symlink already exists or not needed${NC}"
ldconfig
echo -e "${GREEN}✓ libpcap configured${NC}"

# Network auto-discovery
echo -e "${YELLOW}[7/10] Discovering network configuration...${NC}"
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)

if [ -z "$DEFAULT_IFACE" ] || [ -z "$GATEWAY" ]; then
    echo -e "${RED}Failed to detect network interface or gateway${NC}"
    exit 1
fi

# Ping gateway to populate ARP table
ping -c 2 "$GATEWAY" &>/dev/null || true
ROUTER_MAC=$(ip neighbor show "$GATEWAY" | awk '{print $5}' | head -n 1)

echo -e "${GREEN}✓ Default Interface: ${DEFAULT_IFACE}${NC}"
echo -e "${GREEN}✓ Gateway: ${GATEWAY}${NC}"
echo -e "${GREEN}✓ Router MAC: ${ROUTER_MAC}${NC}"

# Apply system optimizations
echo -e "${YELLOW}[8/10] Applying high-performance optimizations...${NC}"

# Enable TCP BBR
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

# Apply iptables rules
iptables -t raw -A PREROUTING -p udp --dport 443 -j NOTRACK
iptables -t raw -A OUTPUT -p udp --sport 443 -j NOTRACK
iptables -t mangle -A POSTROUTING -p tcp --tcp-flags RST RST -j DROP

# Save iptables rules
netfilter-persistent save &>/dev/null || iptables-save > /etc/iptables/rules.v4

echo -e "${GREEN}✓ Optimizations applied${NC}"

# Create config directory
mkdir -p /etc/paqet

# Create paqet client config - EXTREME SPEED MODE
cat > /etc/paqet/config.json <<EOF
{
  "mode": "client",
  "server": "${SERVER_IP}:443",
  "secret": "${SECRET_KEY}",
  "iface": "${DEFAULT_IFACE}",
  "gateway_mac": "${ROUTER_MAC}",
  "socks5": "0.0.0.0:1080",
  "mtu": 1500,
  "kcp": {
    "mode": "fast3",
    "conn": 16,
    "mtu": 1400,
    "sndwnd": 8192,
    "rcvwnd": 8192,
    "datashard": 10,
    "parityshard": 3,
    "dscp": 46,
    "nocongestion": 1,
    "acknodelay": true,
    "nodelay": 1,
    "interval": 10,
    "resend": 2,
    "nc": 1
  }
}
EOF

# Install and configure proxychains4
echo -e "${YELLOW}[9/10] Installing and configuring proxychains4...${NC}"

# Clone and build proxychains-ng
if [ ! -d "/tmp/proxychains-ng" ]; then
    git clone https://github.com/rofl0r/proxychains-ng.git /tmp/proxychains-ng &>/dev/null
fi

cd /tmp/proxychains-ng
./configure --prefix=/usr --sysconfdir=/etc &>/dev/null
make &>/dev/null
make install &>/dev/null
cd - &>/dev/null

# Configure proxychains to use paqet SOCKS5
cat > /etc/proxychains4.conf <<EOF
# Proxychains configuration for Paqet tunnel
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 1080
EOF

echo -e "${GREEN}✓ Proxychains4 installed and configured${NC}"

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
ExecStart=/usr/local/bin/paqet -config /etc/paqet/config.json

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

# Enable and start service
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
echo -e "${YELLOW}Testing the tunnel:${NC}"
echo -e "  ${BLUE}proxychains4 curl -4 ifconfig.me${NC}"
echo -e "  ${BLUE}proxychains4 curl https://www.google.com${NC}"
echo ""
echo -e "Service status: ${GREEN}$(systemctl is-active paqet)${NC}"
echo -e "Check logs: ${BLUE}journalctl -u paqet -f${NC}"
echo ""
