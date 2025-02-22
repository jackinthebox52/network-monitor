#!/bin/bash
# basic-installer.sh - Sets up directory structure for network-monitor
# Must be run with sudo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root: sudo bash basic-installer.sh${NC}"
  exit 1
fi

echo -e "${GREEN}Setting up Network Monitor directory structure...${NC}"

SCRIPT_PATH="/usr/local/bin/network-monitor.sh"
SYMLINK_PATH="/usr/local/bin/netmon"

# Copy the script to its location
if [ -f "./network-monitor.sh" ]; then
  echo -e "${YELLOW}Installing main script...${NC}"
  cp "./network-monitor.sh" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  
  # Create symlink
  ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
else
  echo -e "${RED}Error: network-monitor.sh not found in current directory${NC}"
  echo -e "${YELLOW}Please make sure network-monitor.sh is in the same directory as this installer${NC}"
  exit 1
fi

# Create directories
echo -e "${YELLOW}Creating configuration directories...${NC}"
mkdir -p /etc/network-monitor
touch /var/log/network-monitor.log

# Set permissions
chmod 750 /etc/network-monitor
chmod 640 /var/log/network-monitor.log

# Create example configuration files
echo -e "${YELLOW}Creating example configuration files...${NC}"

# Example thresholds.conf
cat > "/etc/network-monitor/thresholds-example.conf" << EOF
# Format: interface:threshold_bytes:service
# Example: 5GB threshold for WireGuard
wg0:5368709120:wg-quick@wg0
# Example: 10GB threshold for eth0 (no service)
eth0:10737418240:
EOF

# Empty counters file
touch /etc/network-monitor/counters.dat
chmod 640 /etc/network-monitor/counters.dat

# Dependencies
if ! command -v bc &> /dev/null; then
  echo -e "${YELLOW}The 'bc' package is required but not installed.${NC}"
  read -p "Would you like to install it now? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt-get update -qq
    apt-get install -y bc
  else
    echo -e "${YELLOW}Please install 'bc' manually for proper functionality.${NC}"
  fi
fi

echo -e "${GREEN}Basic setup has been completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create your thresholds.conf file manually (use thresholds-example.conf as a reference)"
echo "   Example: sudo cp /etc/network-monitor/thresholds-example.conf /etc/network-monitor/thresholds.conf"
echo ""
echo "2. Reset counters to start tracking usage:"
echo "   sudo netmon reset-counter all"
echo ""
echo "3. Set up cron jobs if automatic monitoring is desired (optional):"
echo "   Add entries to /etc/cron.d/network-monitor"
echo ""
echo -e "${YELLOW}Example cron file content:${NC}"
echo '# Run network monitor checks every hour'
echo "0 * * * * root /bin/bash $SCRIPT_PATH check all > /dev/null 2>&1"
echo '# Check thresholds every hour'
echo "15 * * * * root /bin/bash $SCRIPT_PATH check-thresholds > /dev/null 2>&1"
echo '# Reset counters on the 1st of each month'
echo "0 0 1 * * root /bin/bash $SCRIPT_PATH reset-counter all > /dev/null 2>&1"
echo ""
echo -e "${GREEN}Setup complete! You can now configure the tool manually.${NC}"