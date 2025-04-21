#!/bin/bash
#
# Node Exporter Installer for Debian-based Systems
# This script installs and configures Prometheus Node Exporter as a systemd service
# With optional support for temperature monitoring and Proxmox integration
#
# Usage:
#   ./install_node_exporter.sh                # Standard installation
#   ./install_node_exporter.sh --temp         # Installation with temperature monitoring
#

set -e

# Default configuration variables
NODE_EXPORTER_VERSION="1.9.1"
NODE_EXPORTER_USER="node_exporter"
NODE_EXPORTER_GROUP="node_exporter"
NODE_EXPORTER_PORT="9100"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/node_exporter"
COLLECTORS_DIR="/var/lib/node_exporter/textfile_collector"
COLLECTORS_ENABLED="cpu,diskstats,filesystem,loadavg,meminfo,netdev,netstat,os,stat,time,vmstat,systemd,uname,textfile"

# Initialize flags
ENABLE_TEMP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --temp)
      ENABLE_TEMP=true
      shift
      ;;
    *)
      # Unknown option
      echo "Unknown option: $1"
      echo "Usage: $0 [--temp] [--proxmox]"
      exit 1
      ;;
  esac
done

# Add temperature collectors if enabled
if [ "$ENABLE_TEMP" = true ]; then
  COLLECTORS_ENABLED="${COLLECTORS_ENABLED},thermal_zone,hwmon"
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

echo -e "${GREEN}=== Prometheus Node Exporter Installer ===${NC}"
echo -e "${YELLOW}This script will install Node Exporter $NODE_EXPORTER_VERSION as a systemd service${NC}"

# Show temperature monitoring status
if [ "$ENABLE_TEMP" = true ]; then
    echo -e "${YELLOW}Temperature monitoring is ENABLED${NC}"
else
    echo -e "${YELLOW}Temperature monitoring is DISABLED (use --temp to enable)${NC}"
fi
echo ""

# Check for required commands
command -v curl >/dev/null 2>&1 || {
    echo -e "${YELLOW}curl is required. Installing...${NC}"
    apt update && apt install -y curl
}

# Create user and group if they don't exist
if ! getent group "$NODE_EXPORTER_GROUP" >/dev/null; then
    echo "Creating group: $NODE_EXPORTER_GROUP"
    groupadd --system "$NODE_EXPORTER_GROUP"
fi

if ! id "$NODE_EXPORTER_USER" >/dev/null 2>&1; then
    echo "Creating user: $NODE_EXPORTER_USER"
    useradd --system --no-create-home --shell /bin/false --gid "$NODE_EXPORTER_GROUP" "$NODE_EXPORTER_USER"
fi

# Create config and collectors directories
echo "Creating configuration directories..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$COLLECTORS_DIR"
chown "$NODE_EXPORTER_USER":"$NODE_EXPORTER_GROUP" "$COLLECTORS_DIR"
chmod 755 "$COLLECTORS_DIR"

# Download and install Node Exporter
echo "Downloading Node Exporter ${NODE_EXPORTER_VERSION}..."
cd /tmp
curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

echo "Extracting Node Exporter..."
tar xzvf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" "$INSTALL_DIR/"
chown "$NODE_EXPORTER_USER":"$NODE_EXPORTER_GROUP" "$INSTALL_DIR/node_exporter"
chmod 755 "$INSTALL_DIR/node_exporter"

# Clean up
rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64" "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=${NODE_EXPORTER_USER}
Group=${NODE_EXPORTER_GROUP}
Type=simple
ExecStart=${INSTALL_DIR}/node_exporter \
    --web.listen-address=:${NODE_EXPORTER_PORT} \
    --collector.disable-defaults \
    --collector.${COLLECTORS_ENABLED//,/ --collector.} \
    --collector.textfile.directory=${COLLECTORS_DIR}

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Get the hostname for node identifier
HOSTNAME=$(hostname)

# Create a text file for custom labels
echo "Creating custom labels file..."
cat > "$CONFIG_DIR/node_exporter.labels" << EOF
# Custom labels for this Node Exporter instance
hostname=${HOSTNAME}
environment=production
EOF

# Configure firewall if ufw is present
if command -v ufw >/dev/null 2>&1; then
    echo "Configuring firewall (ufw)..."
    ufw allow "$NODE_EXPORTER_PORT/tcp" comment "Prometheus Node Exporter"
    echo -e "${YELLOW}Firewall rule added for port $NODE_EXPORTER_PORT${NC}"
fi

# Start and enable service
echo "Starting Node Exporter service..."
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
sleep 2

# Check if service is running
if systemctl is-active --quiet node_exporter; then
    echo -e "${GREEN}Node Exporter has been successfully installed and is running!${NC}"
else
    echo -e "${RED}Node Exporter installation completed but the service is not running. Please check 'systemctl status node_exporter' for details.${NC}"
fi

# Get IP for display purposes
IP_ADDR=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDR" ]; then
    IP_ADDR="localhost"
fi

echo -e "\n${GREEN}=== Installation Summary ===${NC}"
echo -e "Node Exporter version: ${YELLOW}${NODE_EXPORTER_VERSION}${NC}"
echo -e "Binary location: ${YELLOW}${INSTALL_DIR}/node_exporter${NC}"
echo -e "Configuration: ${YELLOW}${CONFIG_DIR}/node_exporter.labels${NC}"
echo -e "Service status: ${YELLOW}$(systemctl is-active node_exporter)${NC}"
echo -e "Metrics URL: ${YELLOW}http://${IP_ADDR}:${NODE_EXPORTER_PORT}/metrics${NC}"
echo -e "Enabled collectors: ${YELLOW}${COLLECTORS_ENABLED}${NC}"
echo
echo -e "${GREEN}To add this host to your Prometheus server, add the following to your prometheus.yml:${NC}"
echo -e "${YELLOW}  - job_name: 'node'
    static_configs:
      - targets: ['${IP_ADDR}:${NODE_EXPORTER_PORT}']
        labels:
          instance: '${HOSTNAME}'${NC}"
echo
echo -e "${GREEN}To test if Node Exporter is working, run:${NC}"
echo -e "${YELLOW}curl http://${IP_ADDR}:${NODE_EXPORTER_PORT}/metrics${NC}"

# If temperature monitoring is enabled, add additional information
if [ "$ENABLE_TEMP" = true ]; then
    echo
    echo -e "${GREEN}=== Temperature Monitoring Notes ===${NC}"
    echo -e "${YELLOW}Temperature monitoring is enabled with thermal_zone and hwmon collectors${NC}"
    echo -e "- CPU temperatures: Look for metrics with ${YELLOW}node_hwmon_*${NC} or ${YELLOW}node_thermal_zone_*${NC} prefixes"
    echo -e "- Disk temperatures: Basic temperature data may be available, but comprehensive disk"
    echo -e "  temperature monitoring requires S.M.A.R.T. monitoring via additional tools"
    echo
    echo -e "To view temperature metrics specifically, run:"
    echo -e "${YELLOW}curl http://${IP_ADDR}:${NODE_EXPORTER_PORT}/metrics | grep -E 'node_hwmon_temp|node_thermal_zone_temp'${NC}"
fi
