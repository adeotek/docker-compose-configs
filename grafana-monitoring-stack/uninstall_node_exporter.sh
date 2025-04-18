#!/bin/bash
#
# Node Exporter Uninstaller for Debian-based Systems
# This script removes Prometheus Node Exporter and related components
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration variables
NODE_EXPORTER_USER="node_exporter"
NODE_EXPORTER_GROUP="node_exporter"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/node_exporter"
COLLECTORS_DIR="/var/lib/node_exporter/textfile_collector"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo privileges${NC}"
    exit 1
fi

echo -e "${RED}=== Prometheus Node Exporter Uninstaller ===${NC}"
echo -e "${YELLOW}This script will completely remove Node Exporter and all related files${NC}"
echo -e "${RED}WARNING: This action cannot be undone!${NC}"
echo

# Ask for confirmation
read -p "Are you sure you want to uninstall Node Exporter? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${GREEN}Uninstallation cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Starting uninstallation process...${NC}"

# Stop and disable the service
echo "Stopping and disabling Node Exporter service..."
systemctl stop node_exporter 2>/dev/null || true
systemctl disable node_exporter 2>/dev/null || true
rm -f /etc/systemd/system/node_exporter.service
systemctl daemon-reload

# Remove cron job if exists (for Proxmox monitoring)
if [ -f /etc/cron.d/proxmox-metrics ]; then
    echo "Removing Proxmox metrics cron job..."
    rm -f /etc/cron.d/proxmox-metrics
fi

# Remove firewall rule if ufw is present
if command -v ufw >/dev/null 2>&1; then
    echo "Removing firewall rules..."
    ufw delete allow 9100/tcp 2>/dev/null || true
fi

# Remove binary files
echo "Removing Node Exporter binary..."
rm -f "${INSTALL_DIR}/node_exporter"

# Remove Proxmox metrics collector if exists
if [ -f /usr/local/bin/proxmox_metrics.py ]; then
    echo "Removing Proxmox metrics collector..."
    rm -f /usr/local/bin/proxmox_metrics.py
fi

# Remove configuration directories
echo "Removing configuration directories..."
rm -rf "${CONFIG_DIR}"
rm -rf /var/lib/node_exporter

# Remove user and group
echo "Removing Node Exporter user and group..."
if id "${NODE_EXPORTER_USER}" >/dev/null 2>&1; then
    userdel "${NODE_EXPORTER_USER}" 2>/dev/null || true
fi
if getent group "${NODE_EXPORTER_GROUP}" >/dev/null; then
    groupdel "${NODE_EXPORTER_GROUP}" 2>/dev/null || true
fi

echo -e "\n${GREEN}=== Uninstallation Complete ===${NC}"
echo -e "Node Exporter has been completely removed from your system."
echo -e "The following components were removed:"
echo -e "- Node Exporter service and binary"
echo -e "- Configuration files and directories"
echo -e "- User and group accounts"
echo -e "- Firewall rules (if applicable)"
echo -e "- Proxmox metrics collector (if installed)"
echo -e "- Scheduled tasks (if configured)"
echo

echo -e "${GREEN}Thank you for using Node Exporter!${NC}"
