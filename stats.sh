#!/bin/bash

#####################################################
# Paqet Tunnel Performance Monitoring Script
# Real-time statistics and performance metrics
#####################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if paqet is running
if ! systemctl is-active --quiet paqet; then
    echo -e "${RED}❌ Paqet service is not running${NC}"
    exit 1
fi

# Get configuration
if [ -f "/etc/paqet/config.json" ]; then
    MODE=$(grep -o '"mode": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4)
    IFACE=$(grep -o '"iface": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4)
else
    echo -e "${RED}❌ Configuration file not found${NC}"
    exit 1
fi

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Paqet Tunnel Performance Monitor                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Information
echo -e "${CYAN}━━━ System Information ━━━${NC}"
echo -e "${GREEN}Mode:${NC}         $MODE"
echo -e "${GREEN}Hostname:${NC}     $(hostname)"
echo -e "${GREEN}Interface:${NC}    $IFACE"
echo -e "${GREEN}Uptime:${NC}       $(uptime -p)"
echo ""

# Service Status
echo -e "${CYAN}━━━ Service Status ━━━${NC}"
STATUS=$(systemctl is-active paqet)
if [ "$STATUS" = "active" ]; then
    echo -e "${GREEN}Status:${NC}       ${GREEN}●${NC} Running"
else
    echo -e "${GREEN}Status:${NC}       ${RED}●${NC} $STATUS"
fi

UPTIME=$(systemctl show paqet --property=ActiveEnterTimestamp --value)
if [ -n "$UPTIME" ]; then
    echo -e "${GREEN}Started:${NC}      $UPTIME"
fi

# Memory Usage
if pgrep -x "paqet" > /dev/null; then
    PID=$(pgrep -x "paqet")
    MEM_MB=$(ps -o rss= -p "$PID" | awk '{printf "%.2f MB", $1/1024}')
    MEM_PCT=$(ps -o %mem= -p "$PID" | awk '{printf "%.2f%%", $1}')
    CPU_PCT=$(ps -o %cpu= -p "$PID" | awk '{printf "%.2f%%", $1}')
    
    echo -e "${GREEN}PID:${NC}          $PID"
    echo -e "${GREEN}Memory:${NC}       $MEM_MB ($MEM_PCT)"
    echo -e "${GREEN}CPU:${NC}          $CPU_PCT"
fi
echo ""

# Network Statistics
echo -e "${CYAN}━━━ Network Statistics ━━━${NC}"

# Get interface stats
if [ -f "/sys/class/net/$IFACE/statistics/rx_bytes" ]; then
    RX_BYTES=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
    TX_BYTES=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
    RX_PACKETS=$(cat /sys/class/net/$IFACE/statistics/rx_packets)
    TX_PACKETS=$(cat /sys/class/net/$IFACE/statistics/tx_packets)
    RX_ERRORS=$(cat /sys/class/net/$IFACE/statistics/rx_errors)
    TX_ERRORS=$(cat /sys/class/net/$IFACE/statistics/tx_errors)
    
    # Convert bytes to human readable
    RX_GB=$(echo "scale=2; $RX_BYTES / 1024 / 1024 / 1024" | bc)
    TX_GB=$(echo "scale=2; $TX_BYTES / 1024 / 1024 / 1024" | bc)
    
    echo -e "${GREEN}Received:${NC}     ${RX_GB} GB ($RX_PACKETS packets)"
    echo -e "${GREEN}Sent:${NC}         ${TX_GB} GB ($TX_PACKETS packets)"
    
    if [ "$RX_ERRORS" -gt 0 ] || [ "$TX_ERRORS" -gt 0 ]; then
        echo -e "${YELLOW}Errors:${NC}       RX: $RX_ERRORS, TX: $TX_ERRORS"
    else
        echo -e "${GREEN}Errors:${NC}       None"
    fi
fi
echo ""

# Connection Statistics (Client mode)
if [ "$MODE" = "client" ]; then
    echo -e "${CYAN}━━━ SOCKS5 Connections ━━━${NC}"
    
    # Count active SOCKS5 connections
    SOCKS_CONNS=$(ss -tn 2>/dev/null | grep -c ':1080')
    echo -e "${GREEN}Active:${NC}       $SOCKS_CONNS connections"
    
    # Show established connections
    if [ "$SOCKS_CONNS" -gt 0 ]; then
        echo -e "\n${BLUE}Active connections:${NC}"
        ss -tn 2>/dev/null | grep ':1080' | awk '{print "  " $5}' | head -n 10
        
        if [ "$SOCKS_CONNS" -gt 10 ]; then
            echo -e "  ${YELLOW}... and $((SOCKS_CONNS - 10)) more${NC}"
        fi
    fi
    echo ""
fi

# Recent Log Entries
echo -e "${CYAN}━━━ Recent Logs (last 5) ━━━${NC}"
journalctl -u paqet -n 5 --no-pager -o short-precise 2>/dev/null | sed 's/^/  /'
echo ""

# Performance Metrics
echo -e "${CYAN}━━━ Performance Metrics ━━━${NC}"

# Check if vnstat is installed
if command -v vnstat &> /dev/null; then
    echo -e "${GREEN}Today's Traffic:${NC}"
    vnstat -i "$IFACE" --oneline 2>/dev/null | awk -F\; '{print "  RX: " $9 ", TX: " $10}'
else
    echo -e "${YELLOW}Install vnstat for detailed traffic statistics:${NC}"
    echo -e "  apt install vnstat -y"
fi
echo ""

# Quick bandwidth test
echo -e "${CYAN}━━━ Live Bandwidth (10 second sample) ━━━${NC}"
echo -e "${YELLOW}Sampling...${NC}"

# Get initial values
RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
sleep 10
RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)

# Calculate rates
RX_RATE=$(echo "scale=2; ($RX2 - $RX1) / 10 / 1024" | bc)
TX_RATE=$(echo "scale=2; ($TX2 - $TX1) / 10 / 1024" | bc)

echo -e "${GREEN}Download:${NC}     ${RX_RATE} KB/s"
echo -e "${GREEN}Upload:${NC}       ${TX_RATE} KB/s"
echo ""

# Footer
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Refresh: ./stats.sh  |  Logs: journalctl -u paqet -f    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

exit 0
