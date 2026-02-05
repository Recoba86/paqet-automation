#!/bin/bash

#####################################################
# Paqet Tunnel Configuration Backup Script
# Backs up all critical configuration files
#####################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="/root/paqet-backups"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="paqet-backup-${TIMESTAMP}.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}   Paqet Configuration Backup Tool    ${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Check if paqet is installed
if [ ! -f "/usr/local/bin/paqet" ]; then
    echo -e "${YELLOW}Warning: Paqet binary not found${NC}"
fi

# Create temporary directory for backup
TEMP_DIR=$(mktemp -d)

echo -e "${YELLOW}[1/5] Collecting configuration files...${NC}"

# Copy configuration files
if [ -f "/etc/paqet/config.json" ]; then
    mkdir -p "$TEMP_DIR/etc/paqet"
    cp /etc/paqet/config.json "$TEMP_DIR/etc/paqet/"
    echo -e "${GREEN}✓ Config file${NC}"
else
    echo -e "${YELLOW}⚠ Config file not found${NC}"
fi

echo -e "${YELLOW}[2/5] Collecting systemd service...${NC}"

# Copy systemd service
if [ -f "/etc/systemd/system/paqet.service" ]; then
    mkdir -p "$TEMP_DIR/etc/systemd/system"
    cp /etc/systemd/system/paqet.service "$TEMP_DIR/etc/systemd/system/"
    echo -e "${GREEN}✓ Systemd service${NC}"
else
    echo -e "${YELLOW}⚠ Systemd service not found${NC}"
fi

echo -e "${YELLOW}[3/5] Collecting network settings...${NC}"

# Save current network info for reference
mkdir -p "$TEMP_DIR/info"
ip route > "$TEMP_DIR/info/routes.txt" 2>/dev/null
ip addr > "$TEMP_DIR/info/interfaces.txt" 2>/dev/null
ip neighbor > "$TEMP_DIR/info/arp.txt" 2>/dev/null
echo -e "${GREEN}✓ Network information${NC}"

echo -e "${YELLOW}[4/5] Saving version info...${NC}"

# Save version and metadata
cat > "$TEMP_DIR/info/backup_info.txt" <<EOF
Backup Date: $(date)
Hostname: $(hostname)
Paqet Version: $(/usr/local/bin/paqet -version 2>&1 || echo "unknown")
Service Status: $(systemctl is-active paqet 2>/dev/null || echo "unknown")
EOF
echo -e "${GREEN}✓ Version information${NC}"

echo -e "${YELLOW}[5/5] Creating archive...${NC}"

# Create compressed archive
cd "$TEMP_DIR" || exit 1
tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" . 2>/dev/null

# Cleanup
cd - > /dev/null || exit 1
rm -rf "$TEMP_DIR"

# Verify backup
if [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
    echo -e "${GREEN}✓ Backup created${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}       Backup Completed!               ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}File:${NC}     ${BACKUP_FILE}"
    echo -e "  ${GREEN}Location:${NC} ${BACKUP_DIR}"
    echo -e "  ${GREEN}Size:${NC}     ${BACKUP_SIZE}"
    echo ""
    
    # List all backups
    echo -e "${BLUE}Available backups:${NC}"
    ls -lh "$BACKUP_DIR" | grep "paqet-backup" | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    
    # Keep only last 5 backups
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/paqet-backup-*.tar.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        echo -e "${YELLOW}Cleaning old backups (keeping last 5)...${NC}"
        ls -t "$BACKUP_DIR"/paqet-backup-*.tar.gz | tail -n +6 | xargs rm -f
        echo -e "${GREEN}✓ Cleanup complete${NC}"
    fi
    
else
    echo -e "${RED}✗ Backup failed${NC}"
    exit 1
fi

echo -e "${BLUE}Restore command:${NC}"
echo -e "  tar -xzf ${BACKUP_DIR}/${BACKUP_FILE} -C /"
echo ""

exit 0
