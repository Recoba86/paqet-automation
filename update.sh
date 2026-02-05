#!/bin/bash

#####################################################
# Paqet Tunnel Update Script
# Updates only the binary without touching configs
#####################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Paqet Tunnel Update Checker              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

# Check if paqet is installed
if [ ! -f "/usr/local/bin/paqet" ]; then
    echo -e "${RED}Paqet is not installed. Please run server_setup.sh or client_setup.sh first.${NC}"
    exit 1
fi

# Get current version
echo -e "${YELLOW}[1/5] Checking current version...${NC}"
CURRENT_VERSION=$(/usr/local/bin/paqet -version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
echo -e "${GREEN}✓ Current version: ${CURRENT_VERSION}${NC}"

# Fetch latest release info from GitHub
echo -e "${YELLOW}[2/5] Fetching latest release from GitHub...${NC}"
GITHUB_API="https://api.github.com/repos/hanselime/paqet/releases/latest"
RELEASE_INFO=$(curl -s "$GITHUB_API")

if [ -z "$RELEASE_INFO" ]; then
    echo -e "${RED}Failed to fetch release information from GitHub${NC}"
    exit 1
fi

LATEST_VERSION=$(echo "$RELEASE_INFO" | jq -r '.tag_name')
echo -e "${GREEN}✓ Latest version: ${LATEST_VERSION}${NC}"

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo ""
    echo -e "${GREEN}✓ You are already running the latest version!${NC}"
    echo ""
    exit 0
fi

echo ""
echo -e "${YELLOW}New version available: ${CURRENT_VERSION} → ${LATEST_VERSION}${NC}"
read -p "Do you want to update? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Update cancelled.${NC}"
    exit 0
fi

# Detect system architecture
echo -e "${YELLOW}[3/5] Detecting system architecture...${NC}"
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

# Download new version
echo -e "${YELLOW}[4/5] Downloading new version...${NC}"
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | contains(\"linux\") and contains(\"${ARCH_NAME}\")) | .browser_download_url" | head -n 1)

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Could not find download URL for linux-${ARCH_NAME}${NC}"
    exit 1
fi

wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/paqet_new.tar.gz

# Stop service, update binary, restart service
echo -e "${YELLOW}[5/5] Updating binary and restarting service...${NC}"

# Stop service
systemctl stop paqet

# Backup current binary
cp /usr/local/bin/paqet /usr/local/bin/paqet.backup

# Extract and install new binary
tar -xzf /tmp/paqet_new.tar.gz -C /tmp/
chmod +x /tmp/paqet
mv /tmp/paqet /usr/local/bin/paqet
rm -f /tmp/paqet_new.tar.gz

# Restart service
systemctl start paqet

# Verify service is running
sleep 2
if systemctl is-active --quiet paqet; then
    echo -e "${GREEN}✓ Service restarted successfully${NC}"
    rm -f /usr/local/bin/paqet.backup
else
    echo -e "${RED}✗ Service failed to start. Restoring backup...${NC}"
    mv /usr/local/bin/paqet.backup /usr/local/bin/paqet
    systemctl start paqet
    echo -e "${YELLOW}Backup restored. Please check logs: journalctl -u paqet -n 50${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Update Complete!                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}Updated:${NC}       ${CURRENT_VERSION} → ${LATEST_VERSION}"
echo -e "  ${GREEN}Status:${NC}        $(systemctl is-active paqet)"
echo -e "  ${GREEN}Config:${NC}        Preserved (no changes)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Check logs: ${BLUE}journalctl -u paqet -f${NC}"
echo ""
