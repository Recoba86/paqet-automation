#!/bin/bash

#####################################################
# Paqet Tunnel Management Dashboard
# Unified interface for all management tasks
#####################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show header
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Paqet Tunnel Management Dashboard                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to show quick status
show_quick_status() {
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}● Service Status: Running${NC}"
    else
        echo -e "${RED}● Service Status: Stopped${NC}"
    fi
    
    if [ -f "/etc/paqet/config.json" ]; then
        MODE=$(grep -o '"mode": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4)
        echo -e "${CYAN}● Mode: ${MODE}${NC}"
    fi
    
    if pgrep -x "paqet" > /dev/null; then
        MEM=$(ps -o %mem= -p $(pgrep -x "paqet") | awk '{printf "%.1f%%", $1}')
        echo -e "${CYAN}● Memory: ${MEM}${NC}"
    fi
    echo ""
}

# Main menu
show_menu() {
    show_header
    show_quick_status
    
    echo -e "${CYAN}━━━ Service Management ━━━${NC}"
    echo -e "  ${GREEN}1${NC}) Start Service"
    echo -e "  ${GREEN}2${NC}) Stop Service"
    echo -e "  ${GREEN}3${NC}) Restart Service"
    echo -e "  ${GREEN}4${NC}) Service Status"
    echo -e "  ${GREEN}5${NC}) View Logs (Live)"
    echo ""
    
    echo -e "${CYAN}━━━ Monitoring & Testing ━━━${NC}"
    echo -e "  ${GREEN}6${NC}) Health Check"
    echo -e "  ${GREEN}7${NC}) Performance Stats"
    echo -e "  ${GREEN}8${NC}) Test Tunnel"
    echo ""
    
    echo -e "${CYAN}━━━ Maintenance ━━━${NC}"
    echo -e "  ${GREEN}9${NC}) Backup Configuration"
    echo -e "  ${GREEN}10${NC}) Update Paqet"
    echo -e "  ${GREEN}11${NC}) Edit Configuration"
    echo ""
    
    echo -e "${CYAN}━━━ Advanced ━━━${NC}"
    echo -e "  ${GREEN}12${NC}) Show Configuration"
    echo -e "  ${GREEN}13${NC}) Network Information"
    echo -e "  ${GREEN}14${NC}) System Resources"
    echo ""
    
    echo -e "  ${RED}0${NC}) Exit"
    echo ""
    echo -ne "${YELLOW}Select option: ${NC}"
}

# Service management functions
start_service() {
    echo -e "${YELLOW}Starting paqet service...${NC}"
    systemctl start paqet
    sleep 1
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✅ Service started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start service${NC}"
    fi
}

stop_service() {
    echo -e "${YELLOW}Stopping paqet service...${NC}"
    systemctl stop paqet
    sleep 1
    if ! systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✅ Service stopped${NC}"
    else
        echo -e "${RED}❌ Failed to stop service${NC}"
    fi
}

restart_service() {
    echo -e "${YELLOW}Restarting paqet service...${NC}"
    systemctl restart paqet
    sleep 2
    if systemctl is-active --quiet paqet; then
        echo -e "${GREEN}✅ Service restarted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to restart service${NC}"
    fi
}

show_status() {
    systemctl status paqet --no-pager -l
}

view_logs() {
    echo -e "${YELLOW}Showing live logs (Ctrl+C to exit)...${NC}"
    sleep 1
    journalctl -u paqet -f --since today
}

run_health_check() {
    if [ -f "$SCRIPT_DIR/monitor.sh" ]; then
        bash "$SCRIPT_DIR/monitor.sh"
    else
        echo -e "${RED}❌ monitor.sh not found${NC}"
    fi
}

show_stats() {
    if [ -f "$SCRIPT_DIR/stats.sh" ]; then
        bash "$SCRIPT_DIR/stats.sh"
    else
        echo -e "${RED}❌ stats.sh not found${NC}"
    fi
}

run_test() {
    if [ -f "$SCRIPT_DIR/test-tunnel.sh" ]; then
        bash "$SCRIPT_DIR/test-tunnel.sh"
    else
        echo -e "${RED}❌ test-tunnel.sh not found${NC}"
    fi
}

run_backup() {
    if [ -f "$SCRIPT_DIR/backup.sh" ]; then
        bash "$SCRIPT_DIR/backup.sh"
    else
        echo -e "${RED}❌ backup.sh not found${NC}"
    fi
}

run_update() {
    if [ -f "$SCRIPT_DIR/update.sh" ]; then
        bash "$SCRIPT_DIR/update.sh"
    else
        echo -e "${RED}❌ update.sh not found${NC}"
    fi
}

edit_config() {
    if [ -f "/etc/paqet/config.json" ]; then
        echo -e "${YELLOW}Opening configuration file...${NC}"
        ${EDITOR:-nano} /etc/paqet/config.json
        echo -e "${YELLOW}Restart service for changes to take effect${NC}"
    else
        echo -e "${RED}❌ Configuration file not found${NC}"
    fi
}

show_config() {
    if [ -f "/etc/paqet/config.json" ]; then
        echo -e "${CYAN}Current Configuration:${NC}"
        echo ""
        cat /etc/paqet/config.json | jq . 2>/dev/null || cat /etc/paqet/config.json
    else
        echo -e "${RED}❌ Configuration file not found${NC}"
    fi
}

show_network_info() {
    echo -e "${CYAN}━━━ Network Information ━━━${NC}"
    echo ""
    
    if [ -f "/etc/paqet/config.json" ]; then
        IFACE=$(grep -o '"iface": "[^"]*"' /etc/paqet/config.json | cut -d'"' -f4)
        echo -e "${GREEN}Interface:${NC} $IFACE"
        echo ""
        ip addr show "$IFACE" 2>/dev/null
        echo ""
        echo -e "${GREEN}Routes:${NC}"
        ip route show dev "$IFACE" 2>/dev/null
        echo ""
        echo -e "${GREEN}Gateway:${NC}"
        ip route | grep default
    else
        echo -e "${RED}❌ Configuration file not found${NC}"
    fi
}

show_resources() {
    echo -e "${CYAN}━━━ System Resources ━━━${NC}"
    echo ""
    
    # CPU
    echo -e "${GREEN}CPU Usage:${NC}"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/" | awk '{print "  " 100 - $1"%"}'
    
    # Memory
    echo -e "${GREEN}Memory Usage:${NC}"
    free -h | grep Mem | awk '{print "  " $3 " / " $2 " (" int($3/$2 * 100) "%)"}'
    
    # Disk
    echo -e "${GREEN}Disk Usage:${NC}"
    df -h / | tail -1 | awk '{print "  " $3 " / " $2 " (" $5 ")"}'
    
    # Paqet process
    if pgrep -x "paqet" > /dev/null; then
        echo ""
        echo -e "${GREEN}Paqet Process:${NC}"
        ps aux | grep "[p]aqet" | awk '{print "  CPU: " $3 "%, MEM: " $4 "%, RSS: " $6 " KB"}'
    fi
}

# Main loop
while true; do
    show_menu
    read -r choice
    echo ""
    
    case $choice in
        1) start_service ;;
        2) stop_service ;;
        3) restart_service ;;
        4) show_status ;;
        5) view_logs ;;
        6) run_health_check ;;
        7) show_stats ;;
        8) run_test ;;
        9) run_backup ;;
        10) run_update ;;
        11) edit_config ;;
        12) show_config ;;
        13) show_network_info ;;
        14) show_resources ;;
        0) 
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    echo -ne "${YELLOW}Press Enter to continue...${NC}"
    read
done
