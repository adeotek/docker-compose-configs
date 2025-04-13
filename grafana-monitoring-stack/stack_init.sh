#!/bin/bash

set -e

# Default configuration variables
STAK_ROOT_DIR="/opt/monitoring"

if [ -z "$1" ]; then
  echo "${YELLOW}Using default stack root directory: ${NC}$STAK_ROOT_DIR"
else
  STAK_ROOT_DIR="${1%/}"
  echo "${YELLOW}Using provided stack root directory: ${NC}$STAK_ROOT_DIR"
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

# Create root directory and copy docker compose and env files
mkdir -p "$STAK_ROOT_DIR"
if [ ! -f "$STAK_ROOT_DIR/docker-compose.yml" ]; then
  cp docker-compose.yml "$STAK_ROOT_DIR"
else
  echo -e "${YELLOW}docker-compose.yml already exists in $STAK_ROOT_DIR. Skipping copy.${NC}"
fi
if [ ! -f "$STAK_ROOT_DIR/.env" ]; then
  cp .env.sample "$STAK_ROOT_DIR/.env"
else
  echo -e "${YELLOW}.env already exists in $STAK_ROOT_DIR. Skipping copy.${NC}"
fi
chmod 600 "$STAK_ROOT_DIR/.env"

# Create directories and copy config for Prometheus
if [ ! -f "$STAK_ROOT_DIR/prometheus/config/prometheus.yml" ]; then
  mkdir -p "$STAK_ROOT_DIR/prometheus/config"
  mkdir -p "$STAK_ROOT_DIR/prometheus/data"
  cp configs/prometheus-config.yml "$STAK_ROOT_DIR/prometheus/config/prometheus.yml"
else
  echo -e "${YELLOW}prometheus.yml already exists in $STAK_ROOT_DIR/prometheus/config. Skipping copy.${NC}"
fi
# Set permissions for Prometheus directories
chown -R 65534:65534 "$STAK_ROOT_DIR/prometheus/data"
chown -R 65534:65534 "$STAK_ROOT_DIR/prometheus/config"
chmod -R 755 "$STAK_ROOT_DIR/prometheus"

# Create directories and copy config for Loki
if [ ! -f "$STAK_ROOT_DIR/loki/config/loki-config.yml" ]; then
  mkdir -p "$STAK_ROOT_DIR/loki/config"
  mkdir -p "$STAK_ROOT_DIR/loki/data"
  cp configs/loki-config.yml "$STAK_ROOT_DIR/loki/config/loki-config.yml"
else
  echo -e "${YELLOW}loki-config.yml already exists in $STAK_ROOT_DIR/loki/config. Skipping copy.${NC}"
fi
# Set permissions for Loki directories
chown -R 10001:10001 "$STAK_ROOT_DIR/loki/data"
chown -R 10001:10001 "$STAK_ROOT_DIR/loki/config"
chmod -R 755 "$STAK_ROOT_DIR/loki"

# Create directories and copy config for Promtail
if [ ! -f "$STAK_ROOT_DIR/promtail/config/promtail-config.yml" ]; then
  mkdir -p "$STAK_ROOT_DIR/promtail/config"
  cp configs/promtail-config.yml "$STAK_ROOT_DIR/promtail/config/promtail-config.yml"
else
  echo -e "${YELLOW}promtail-config.yml already exists in $STAK_ROOT_DIR/promtail/config. Skipping copy.${NC}"
fi
# Set permissions for Promtail directories
chmod -R 755 /opt/monitoring/promtail

# Create directories and copy config for Grafana
mkdir -p "$STAK_ROOT_DIR/grafana/data"
mkdir -p "$STAK_ROOT_DIR/grafana/provisioning/{dashboards,datasources}"
mkdir -p "$STAK_ROOT_DIR/grafana/provisioning/dashboards/{homelab,monitoring}"
if [ ! -f "$STAK_ROOT_DIR/grafana/provisioning/dashboards/dashboards.yml" ]; then
  cp configs/grafana-provisioning/dashboards/dashboards.yml "$STAK_ROOT_DIR/grafana/provisioning/dashboards/dashboards.yml"
else
  echo -e "${YELLOW}dashboards.yml already exists in $STAK_ROOT_DIR/grafana/provisioning/dashboards. Skipping copy.${NC}"
fi
if [ ! -f "$STAK_ROOT_DIR/grafana/provisioning/dashboards/homelab/cadvisor-dashboard.json" ]; then
  cp configs/grafana-provisioning/dashboards/homelab/cadvisor-dashboard.json "$STAK_ROOT_DIR/grafana/provisioning/dashboards/homelab/cadvisor-dashboard.json"
fi
if [ ! -f "$STAK_ROOT_DIR/grafana/provisioning/dashboards/homelab/node-exporter-dashboard.json" ]; then
  cp configs/grafana-provisioning/dashboards/homelab/node-exporter-dashboard.json "$STAK_ROOT_DIR/grafana/provisioning/dashboards/homelab/node-exporter-dashboard.json"
fi
if [ ! -f "$STAK_ROOT_DIR/grafana/provisioning/datasources/datasources.yml" ]; then
  cp configs/grafana-provisioning/datasources/datasources.yml "$STAK_ROOT_DIR/grafana/provisioning/datasources/datasources.yml"
else
  echo -e "${YELLOW}datasources.yml already exists in $STAK_ROOT_DIR/grafana/provisioning/datasources. Skipping copy.${NC}"
fi
# Set permissions for Grafana directories
chown -R 472:472 "$STAK_ROOT_DIR/grafana"
chmod -R 755 "$STAK_ROOT_DIR/grafana"
