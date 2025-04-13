#!/bin/bash
#
# Node Exporter Installer for Debian-based Systems
# This script installs and configures Prometheus Node Exporter as a systemd service
# With optional support for temperature monitoring and Proxmox integration
#
# Usage:
#   ./install_node_exporter.sh                # Standard installation
#   ./install_node_exporter.sh --temp         # Installation with temperature monitoring
#   ./install_node_exporter.sh --proxmox      # Installation with Proxmox monitoring
#   ./install_node_exporter.sh --temp --proxmox  # Both temperature and Proxmox monitoring
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
COLLECTORS_ENABLED="cpu,diskstats,filesystem,loadavg,meminfo,netdev,netstat,stat,time,vmstat,systemd,uname,textfile"

# Initialize flags
ENABLE_TEMP=false
ENABLE_PROXMOX=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --temp)
      ENABLE_TEMP=true
      shift
      ;;
    --proxmox)
      ENABLE_PROXMOX=true
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

# Check for Proxmox and show status
if [ "$ENABLE_PROXMOX" = true ]; then
    echo -e "${YELLOW}Proxmox monitoring is ENABLED${NC}"

    # Check if we're actually on a Proxmox system
    if [ ! -f "/usr/bin/pvesh" ] && [ ! -f "/usr/sbin/pveversion" ]; then
        echo -e "${RED}Warning: Proxmox tools not detected. Are you sure this is a Proxmox host?${NC}"
        echo -e "${YELLOW}Continuing with installation, but Proxmox monitoring may not work correctly.${NC}"
    fi
else
    echo -e "${YELLOW}Proxmox monitoring is DISABLED (use --proxmox to enable)${NC}"
fi
echo ""

# Check for required commands
command -v curl >/dev/null 2>&1 || {
    echo -e "${YELLOW}curl is required. Installing...${NC}"
    apt update && apt install -y curl
}

# Install additional dependencies if Proxmox monitoring is enabled
if [ "$ENABLE_PROXMOX" = true ]; then
    echo -e "${YELLOW}Installing dependencies for Proxmox monitoring...${NC}"
    apt update && apt install -y jq python3 python3-proxmoxer python3-requests
fi

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

# Install Proxmox metrics collector if enabled
if [ "$ENABLE_PROXMOX" = true ]; then
    echo "Installing Proxmox metrics collector..."
    cat > /usr/local/bin/proxmox_metrics.py << 'EOF'
#!/usr/bin/env python3
"""
Proxmox metrics collector for Prometheus Node Exporter
Collects metrics from Proxmox API and writes them to a file in Prometheus format
for consumption by the Node Exporter textfile collector.
"""

import json
import os
import sys
import time
from datetime import datetime
from proxmoxer import ProxmoxAPI
import socket

# Configuration
OUTPUT_FILE = '/var/lib/node_exporter/textfile_collector/proxmox.prom'
HOSTNAME = socket.gethostname()

def get_proxmox_connection():
    """Connect to the Proxmox API using various authentication methods."""
    # Try different authentication methods in order of preference

    # 1. Try token-based authentication if a token file exists
    token_file = '/etc/node_exporter/proxmox_token.conf'
    if os.path.exists(token_file):
        try:
            with open(token_file, 'r') as f:
                config = json.load(f)

            return ProxmoxAPI(
                config.get('host', HOSTNAME),
                user=config.get('user'),
                token_name=config.get('token_name'),
                token_value=config.get('token_value'),
                verify_ssl=False
            )
        except Exception as e:
            print(f"# Warning: Token auth failed: {e}", file=sys.stderr)

    # 2. Try password-based authentication if password file exists
    password_file = '/etc/node_exporter/proxmox_auth.conf'
    if os.path.exists(password_file):
        try:
            with open(password_file, 'r') as f:
                config = json.load(f)

            return ProxmoxAPI(
                config.get('host', HOSTNAME),
                user=config.get('user'),
                password=config.get('password'),
                verify_ssl=False
            )
        except Exception as e:
            print(f"# Warning: Password auth failed: {e}", file=sys.stderr)

    print(f"# ERROR: All authentication methods failed", file=sys.stderr)
    return None

def get_node_metrics(proxmox):
    """Get node-level metrics."""
    metrics = []

    try:
        # Get the current node status
        node_status = proxmox.nodes(HOSTNAME).status.get()

        # Basic node metrics
        metrics.append(f'proxmox_node_cpu_usage{{node="{HOSTNAME}"}} {node_status["cpu"]:.6f}')
        metrics.append(f'proxmox_node_memory_usage_bytes{{node="{HOSTNAME}"}} {node_status["memory"]["used"]}')
        metrics.append(f'proxmox_node_memory_total_bytes{{node="{HOSTNAME}"}} {node_status["memory"]["total"]}')
        metrics.append(f'proxmox_node_uptime_seconds{{node="{HOSTNAME}"}} {node_status["uptime"]}')

        # Storage metrics
        for storage in proxmox.nodes(HOSTNAME).storage.get():
            storage_id = storage['storage']
            if 'used' in storage and 'total' in storage:
                metrics.append(f'proxmox_storage_used_bytes{{node="{HOSTNAME}",storage="{storage_id}"}} {storage["used"]}')
                metrics.append(f'proxmox_storage_total_bytes{{node="{HOSTNAME}",storage="{storage_id}"}} {storage["total"]}')

    except Exception as e:
        print(f"Error collecting node metrics: {e}", file=sys.stderr)

    return metrics

def get_vm_metrics(proxmox):
    """Get VM-level metrics."""
    metrics = []

    try:
        # Get all VMs and containers
        for vm in proxmox.nodes(HOSTNAME).qemu.get():
            vm_id = vm['vmid']
            vm_name = vm.get('name', f'vm-{vm_id}')
            vm_status = vm['status']  # 'running', 'stopped', etc.

            # Basic VM status (1 for running, 0 for stopped)
            metrics.append(f'proxmox_vm_running{{node="{HOSTNAME}",vmid="{vm_id}",name="{vm_name}"}} {1 if vm_status == "running" else 0}')

            # If VM is running, get detailed stats
            if vm_status == 'running':
                try:
                    vm_stats = proxmox.nodes(HOSTNAME).qemu(vm_id).status.current.get()

                    if 'cpu' in vm_stats:
                        metrics.append(f'proxmox_vm_cpu_usage{{node="{HOSTNAME}",vmid="{vm_id}",name="{vm_name}"}} {vm_stats["cpu"]:.6f}')

                    if 'mem' in vm_stats:
                        metrics.append(f'proxmox_vm_memory_usage_bytes{{node="{HOSTNAME}",vmid="{vm_id}",name="{vm_name}"}} {vm_stats["mem"]}')

                    if 'maxmem' in vm_stats:
                        metrics.append(f'proxmox_vm_memory_total_bytes{{node="{HOSTNAME}",vmid="{vm_id}",name="{vm_name}"}} {vm_stats["maxmem"]}')
                except Exception as e:
                    print(f"Error collecting stats for VM {vm_id}: {e}", file=sys.stderr)

    except Exception as e:
        print(f"Error collecting VM metrics: {e}", file=sys.stderr)

    # Get all LXC containers
    try:
        for ct in proxmox.nodes(HOSTNAME).lxc.get():
            ct_id = ct['vmid']
            ct_name = ct.get('name', f'ct-{ct_id}')
            ct_status = ct['status']  # 'running', 'stopped', etc.

            # Basic container status (1 for running, 0 for stopped)
            metrics.append(f'proxmox_ct_running{{node="{HOSTNAME}",ctid="{ct_id}",name="{ct_name}"}} {1 if ct_status == "running" else 0}')

            # If container is running, get detailed stats
            if ct_status == 'running':
                try:
                    ct_stats = proxmox.nodes(HOSTNAME).lxc(ct_id).status.current.get()

                    if 'cpu' in ct_stats:
                        metrics.append(f'proxmox_ct_cpu_usage{{node="{HOSTNAME}",ctid="{ct_id}",name="{ct_name}"}} {ct_stats["cpu"]:.6f}')

                    if 'mem' in ct_stats:
                        metrics.append(f'proxmox_ct_memory_usage_bytes{{node="{HOSTNAME}",ctid="{ct_id}",name="{ct_name}"}} {ct_stats["mem"]}')

                    if 'maxmem' in ct_stats:
                        metrics.append(f'proxmox_ct_memory_total_bytes{{node="{HOSTNAME}",ctid="{ct_id}",name="{ct_name}"}} {ct_stats["maxmem"]}')
                except Exception as e:
                    print(f"Error collecting stats for container {ct_id}: {e}", file=sys.stderr)

    except Exception as e:
        print(f"Error collecting container metrics: {e}", file=sys.stderr)

    return metrics

def main():
    """Main function to collect and write metrics."""
    start_time = time.time()

    # Add a timestamp as a comment
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = [f"# Proxmox metrics collected at {current_time}"]

    # Get a connection to the Proxmox API
    proxmox = get_proxmox_connection()
    if not proxmox:
        lines.append("# ERROR: Could not connect to Proxmox API")
        with open(OUTPUT_FILE, 'w') as f:
            f.write('\n'.join(lines) + '\n')
        return

    # Collect node metrics
    lines.extend(get_node_metrics(proxmox))

    # Collect VM metrics
    lines.extend(get_vm_metrics(proxmox))

    # Add execution time as a metric
    execution_time = time.time() - start_time
    lines.append(f'proxmox_collector_execution_time_seconds{{node="{HOSTNAME}"}} {execution_time:.6f}')

    # Write metrics to file
    with open(OUTPUT_FILE, 'w') as f:
        f.write('\n'.join(lines) + '\n')

    print(f"Metrics written to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
EOF

    chmod +x /usr/local/bin/proxmox_metrics.py

    # Create a template for the authentication configuration file
    echo "Creating Proxmox authentication configuration template..."
    cat > /etc/node_exporter/proxmox_auth.conf.template << EOF
{
    "host": "localhost",
    "user": "root@pam",
    "password": "your_proxmox_password"
}
EOF

    cat > /etc/node_exporter/proxmox_token.conf.template << EOF
{
    "host": "localhost",
    "user": "root@pam",
    "token_name": "your_token_id",
    "token_value": "your_token_secret"
}
EOF

    # Set secure permissions for the template files
    chmod 600 /etc/node_exporter/proxmox_auth.conf.template
    chmod 600 /etc/node_exporter/proxmox_token.conf.template

    # Provide instructions for authentication
    echo
    echo -e "${YELLOW}Proxmox API authentication required${NC}"
    echo -e "To configure authentication, edit one of these files and remove the .template extension:"
    echo -e "  - For password auth: ${YELLOW}/etc/node_exporter/proxmox_auth.conf.template${NC}"
    echo -e "  - For token auth: ${YELLOW}/etc/node_exporter/proxmox_token.conf.template${NC}"
    echo

    # Create cron job to run the collector every minute
    echo "Setting up cron job for Proxmox metrics collection..."
    cat > /etc/cron.d/proxmox-metrics << EOF
# Run Proxmox metrics collector every minute
* * * * * root /usr/local/bin/proxmox_metrics.py > /dev/null 2>&1
EOF

    # Run the collector once to make sure it works
    /usr/local/bin/proxmox_metrics.py
fi

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
echo -e "${YELLOW}Required: Configure Proxmox API Authentication${NC}"
echo -e "To complete the setup, you must configure authentication by following these steps:"
echo
echo -e "1. For password-based authentication:"
echo -e "   ${YELLOW}sudo cp /etc/node_exporter/proxmox_auth.conf.template /etc/node_exporter/proxmox_auth.conf${NC}"
echo -e "   ${YELLOW}sudo nano /etc/node_exporter/proxmox_auth.conf${NC}"
echo -e "   Edit the file to set your Proxmox credentials"
echo -e "   ${YELLOW}sudo chmod 600 /etc/node_exporter/proxmox_auth.conf${NC}"
echo
echo -e "2. OR for token-based authentication (more secure):"
echo -e "   ${YELLOW}sudo cp /etc/node_exporter/proxmox_token.conf.template /etc/node_exporter/proxmox_token.conf${NC}"
echo -e "   ${YELLOW}sudo nano /etc/node_exporter/proxmox_token.conf${NC}"
echo -e "   Edit the file to set your API token details"
echo -e "   ${YELLOW}sudo chmod 600 /etc/node_exporter/proxmox_token.conf${NC}"
echo
echo -e "To test if authentication works:"
echo -e "   ${YELLOW}sudo /usr/local/bin/proxmox_metrics.py${NC}"
echo -e "   ${YELLOW}cat ${COLLECTORS_DIR}/proxmox.prom${NC}"
echo
echo -e "To view Proxmox metrics in Node Exporter:"
echo -e "   ${YELLOW}curl http://${IP_ADDR}:${NODE_EXPORTER_PORT}/metrics | grep proxmox${NC}"
