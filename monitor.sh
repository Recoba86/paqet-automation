#!/bin/bash

#####################################################
# Paqet Tunnel Health Check & Auto-Recovery Script
# Monitors service status and automatically restarts if needed
#####################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_FILE="/var/log/paqet-monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to log messages
log_message() {
    echo -e "${TIMESTAMP} - $1" | tee -a "$LOG_FILE"
}

# Check if paqet service exists
if ! systemctl list-unit-files | grep -q "paqet.service"; then
    echo -e "${RED}❌ Paqet service not installed${NC}"
    exit 1
fi

# Check service status
if systemctl is-active --quiet paqet; then
    echo -e "${GREEN}✅ Service is running${NC}"
    
    # Additional health checks
    
    # Check if process is actually running
    if pgrep -x "paqet" > /dev/null; then
        echo -e "${GREEN}✅ Process is active${NC}"
    else
        echo -e "${YELLOW}⚠️  Service running but process not found${NC}"
        log_message "WARNING: Service running but process not found - restarting"
        systemctl restart paqet
        sleep 2
    fi
    
    # Check SOCKS5 port (client only)
    if grep -q '"mode": "client"' /etc/paqet/config.json 2>/dev/null; then
        if ss -tuln | grep -q ':1080'; then
            echo -e "${GREEN}✅ SOCKS5 proxy listening on port 1080${NC}"
        else
            echo -e "${RED}❌ SOCKS5 proxy not listening${NC}"
            log_message "ERROR: SOCKS5 proxy not listening - restarting service"
            systemctl restart paqet
            sleep 2
        fi
    fi
    
    # Check memory usage
    MEM_USAGE=$(ps -o %mem,cmd -C paqet | tail -n 1 | awk '{print $1}')
    if [ -n "$MEM_USAGE" ]; then
        MEM_LIMIT=10.0
        if (( $(echo "$MEM_USAGE > $MEM_LIMIT" | bc -l) )); then
            echo -e "${YELLOW}⚠️  High memory usage: ${MEM_USAGE}%${NC}"
            log_message "WARNING: High memory usage: ${MEM_USAGE}%"
        else
            echo -e "${GREEN}✅ Memory usage: ${MEM_USAGE}%${NC}"
        fi
    fi
    
    log_message "INFO: Health check passed - service running normally"
    
else
    echo -e "${RED}❌ Service is not running${NC}"
    log_message "ERROR: Service stopped - attempting restart"
    
    # Attempt to restart
    echo -e "${YELLOW}Attempting to restart service...${NC}"
    systemctl restart paqet
    
    # Wait and check again
    sleep 3
    
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✅ Service restarted successfully${NC}"
        log_message "INFO: Service restarted successfully"
    else
        echo -e "${RED}❌ Failed to restart service${NC}"
        log_message "ERROR: Failed to restart service - manual intervention required"
        
        # Show last error from journal
        echo -e "\n${YELLOW}Last 10 log entries:${NC}"
        journalctl -u paqet -n 10 --no-pager
        
        exit 1
    fi
fi

# Show service uptime
UPTIME=$(systemctl show paqet --property=ActiveEnterTimestamp --value)
if [ -n "$UPTIME" ]; then
    echo -e "\n${GREEN}Service uptime:${NC} Started at $UPTIME"
fi

exit 0
