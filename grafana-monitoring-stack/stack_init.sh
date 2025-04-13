#!/bin/bash

set -e

# Default configuration variables
STAK_ROOT_DIR="/opt/monitoring/"

if [ -z "$1" ]; then
  echo "${YELLOW}Using default stack root directory: ${NC}$STAK_ROOT_DIR"
else
  STAK_ROOT_DIR="${1%/}/"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root or with sudo privileges${NC}"
    exit 1
fi







# # For password-based auth (easier but less secure)
# sudo cp /etc/node_exporter/proxmox_auth.conf.template /etc/node_exporter/proxmox_auth.conf
# sudo nano /etc/node_exporter/proxmox_auth.conf
# sudo chmod 600 /etc/node_exporter/proxmox_auth.conf

# # OR for token-based auth (more secure)
# sudo cp /etc/node_exporter/proxmox_token.conf.template /etc/node_exporter/proxmox_token.conf
# sudo nano /etc/node_exporter/proxmox_token.conf
# sudo chmod 600 /etc/node_exporter/proxmox_token.conf
