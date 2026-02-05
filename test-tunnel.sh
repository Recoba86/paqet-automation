#!/bin/bash

#####################################################
# Paqet Tunnel Testing Script
# Comprehensive tunnel functionality tests
#####################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}   Paqet Tunnel Testing Suite         ${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Determine if this is a server or client
if [ -f "/etc/paqet/config.json" ]; then
    MODE=$(grep -o '"mode": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4)
else
    echo -e "${RED}❌ Configuration file not found${NC}"
    exit 1
fi

echo -e "${BLUE}Mode:${NC} $MODE"
echo ""

# Test 1: Service Status
echo -e "${YELLOW}[Test 1/6] Service Status${NC}"
if systemctl is-active --quiet paqet; then
    echo -e "${GREEN}✅ PASS${NC} - Service is running"
else
    echo -e "${RED}❌ FAIL${NC} - Service is not running"
    exit 1
fi

# Test 2: Process Check
echo -e "${YELLOW}[Test 2/6] Process Check${NC}"
if pgrep -x "paqet" > /dev/null; then
    PID=$(pgrep -x "paqet")
    echo -e "${GREEN}✅ PASS${NC} - Process running (PID: $PID)"
else
    echo -e "${RED}❌ FAIL${NC} - Process not found"
    exit 1
fi

# Test 3: Configuration Validation
echo -e "${YELLOW}[Test 3/6] Configuration Validation${NC}"
if jq empty /etc/paqet/config.json 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC} - Valid JSON configuration"
else
    echo -e "${RED}❌ FAIL${NC} - Invalid configuration file"
    exit 1
fi

if [ "$MODE" = "client" ]; then
    # Client-specific tests
    
    # Test 4: SOCKS5 Port
    echo -e "${YELLOW}[Test 4/6] SOCKS5 Port Check${NC}"
    if ss -tuln | grep -q ':1080'; then
        echo -e "${GREEN}✅ PASS${NC} - SOCKS5 listening on port 1080"
    else
        echo -e "${RED}❌ FAIL${NC} - SOCKS5 not listening"
        exit 1
    fi
    
    # Test 5: Proxychains Installation
    echo -e "${YELLOW}[Test 5/6] Proxychains Check${NC}"
    if command -v proxychains4 &> /dev/null; then
        echo -e "${GREEN}✅ PASS${NC} - Proxychains4 installed"
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - Proxychains4 not found"
    fi
    
    # Test 6: Connection Test
    echo -e "${YELLOW}[Test 6/6] Connection Test${NC}"
    echo -e "  ${BLUE}Testing tunnel connectivity...${NC}"
    
    # Get server IP from config
    SERVER_IP=$(grep -o '"server": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4 | cut -d':' -f1)
    
    # Test with curl through proxy
    if command -v proxychains4 &> /dev/null; then
        EXTERNAL_IP=$(timeout 10 proxychains4 -q curl -s -4 ifconfig.me 2>/dev/null)
        
        if [ -n "$EXTERNAL_IP" ]; then
            echo -e "${GREEN}✅ PASS${NC} - Tunnel working!"
            echo -e "  ${GREEN}Your IP through tunnel:${NC} $EXTERNAL_IP"
            
            if [ "$EXTERNAL_IP" = "$SERVER_IP" ]; then
                echo -e "  ${GREEN}✓ Matches server IP${NC}"
            else
                echo -e "  ${YELLOW}⚠ IP doesn't match server (this might be normal)${NC}"
            fi
        else
            echo -e "${RED}❌ FAIL${NC} - Could not connect through tunnel"
            echo -e "  ${YELLOW}Troubleshooting:${NC}"
            echo -e "    - Check server is running"
            echo -e "    - Verify server IP and secret key"
            echo -e "    - Check firewall rules (UDP 443)"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  SKIP${NC} - Proxychains not available for testing"
    fi
    
elif [ "$MODE" = "server" ]; then
    # Server-specific tests
    
    # Test 4: Port Listening
    echo -e "${YELLOW}[Test 4/6] Port Check${NC}"
    if ss -uln | grep -q ':443'; then
        echo -e "${GREEN}✅ PASS${NC} - Server listening on UDP 443"
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - Port 443 not visible (might be raw socket)"
    fi
    
    # Test 5: Network Interface
    echo -e "${YELLOW}[Test 5/6] Network Interface${NC}"
    IFACE=$(grep -o '"iface": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4)
    if ip link show "$IFACE" &> /dev/null; then
        echo -e "${GREEN}✅ PASS${NC} - Interface $IFACE exists"
    else
        echo -e "${RED}❌ FAIL${NC} - Interface $IFACE not found"
        exit 1
    fi
    
    # Test 6: Public IP Check
    echo -e "${YELLOW}[Test 6/6] Public IP Check${NC}"
    PUBLIC_IP=$(curl -s -4 ifconfig.me 2>/dev/null)
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Server is reachable"
        echo -e "  ${GREEN}Public IP:${NC} $PUBLIC_IP"
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - Could not determine public IP"
    fi
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}   All Tests Passed! ✨                ${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""

# Show logs command
echo -e "${BLUE}View logs:${NC} journalctl -u paqet -f --since today"
echo -e "${BLUE}Check status:${NC} systemctl status paqet"
echo ""

exit 0
