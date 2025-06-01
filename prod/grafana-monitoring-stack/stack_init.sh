#!/bin/bash

set -e

# Default configuration variables
STAK_ROOT_DIR="/opt/monitoring"

if [ -z "$1" ]; then
  echo "${YELLOW}Using default stack root directory: ${NC}$STACK_ROOT_DIR"
else
  STAK_ROOT_DIR="${1%/}"
  echo "${YELLOW}Using provided stack root directory: ${NC}$STACK_ROOT_DIR"
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
mkdir -p "$STACK_ROOT_DIR"
if [ ! -f "$STACK_ROOT_DIR/docker-compose.yml" ]; then
  cp docker-compose.yml "$STACK_ROOT_DIR"
else
  echo -e "${YELLOW}docker-compose.yml already exists in $STACK_ROOT_DIR. Skipping copy.${NC}"
fi
if [ ! -f "$STACK_ROOT_DIR/.env" ]; then
  cp .env.sample "$STACK_ROOT_DIR/.env"
else
  echo -e "${YELLOW}.env already exists in $STACK_ROOT_DIR. Skipping copy.${NC}"
fi
chmod 600 "$STACK_ROOT_DIR/.env"

# Create directories and copy config for VictoriaMetrics
if [ ! -d "$STACK_ROOT_DIR/data/victoriametrics" ]; then
  mkdir -p "$STACK_ROOT_DIR/data/victoriametrics"
fi
# Set permissions for VictoriaMetrics directories
chown -R 65534:65534 "$STACK_ROOT_DIR/data/victoriametrics"
chmod -R 755 "$STACK_ROOT_DIR/victoriametrics"

# Create directories and copy config for Prometheus
if [ ! -f "$STACK_ROOT_DIR/config/prometheus/prometheus.yml" ]; then
  mkdir -p "$STACK_ROOT_DIR/config/prometheus"
  mkdir -p "$STACK_ROOT_DIR/data/prometheus"
  cp configs/prometheus-config.yml "$STACK_ROOT_DIR/config/prometheus/config.yml"
else
  echo -e "${YELLOW}prometheus.yml already exists in $STACK_ROOT_DIR/config/prometheus. Skipping copy.${NC}"
fi
# Set permissions for Prometheus directories
chown -R 65534:65534 "$STACK_ROOT_DIR/data/prometheus"
chown -R 65534:65534 "$STACK_ROOT_DIR/config/prometheus"
chmod -R 755 "$STACK_ROOT_DIR/prometheus"

# Create directories and copy config for Loki
if [ ! -f "$STACK_ROOT_DIR/config/loki/loki-config.yml" ]; then
  mkdir -p "$STACK_ROOT_DIR/config/loki"
  mkdir -p "$STACK_ROOT_DIR/data/loki"
  cp configs/loki-config.yml "$STACK_ROOT_DIR/config/loki/config.yml"
else
  echo -e "${YELLOW}loki-config.yml already exists in $STACK_ROOT_DIR/config/loki. Skipping copy.${NC}"
fi
# Set permissions for Loki directories
chown -R 10001:10001 "$STACK_ROOT_DIR/data/loki"
chown -R 10001:10001 "$STACK_ROOT_DIR/config/loki"
chmod -R 755 "$STACK_ROOT_DIR/loki"

# Create directories and copy config for Promtail
if [ ! -f "$STACK_ROOT_DIR/config/promtail/promtail-config.yml" ]; then
  mkdir -p "$STACK_ROOT_DIR/config/promtail"
  cp configs/promtail-config.yml "$STACK_ROOT_DIR/config/promtail/config.yml"
else
  echo -e "${YELLOW}promtail-config.yml already exists in $STACK_ROOT_DIR/config/promtail. Skipping copy.${NC}"
fi
# Set permissions for Promtail directories
chmod -R 755 /opt/monitoring/promtail

# Create directories and copy config for Grafana
mkdir -p "$STACK_ROOT_DIR/data/grafana"
mkdir -p "$STACK_ROOT_DIR/config/grafana/{dashboards,datasources}"
mkdir -p "$STACK_ROOT_DIR/config/grafana/dashboards/{homelab,monitoring}"
if [ ! -f "$STACK_ROOT_DIR/config/grafana/dashboards/dashboards.yml" ]; then
  cp configs/grafana-provisioning/dashboards/dashboards.yml "$STACK_ROOT_DIR/grafana/config/dashboards/dashboards.yml"
else
  echo -e "${YELLOW}dashboards.yml already exists in $STACK_ROOT_DIR/grafana/config/dashboards. Skipping copy.${NC}"
fi
if [ ! -f "$STACK_ROOT_DIR/grafana/config/dashboards/homelab/cadvisor-dashboard.json" ]; then
  cp configs/grafana-provisioning/dashboards/homelab/cadvisor-dashboard.json "$STACK_ROOT_DIR/grafana/config/dashboards/homelab/cadvisor-dashboard.json"
fi
if [ ! -f "$STACK_ROOT_DIR/grafana/config/dashboards/homelab/node-exporter-dashboard.json" ]; then
  cp configs/grafana-provisioning/dashboards/homelab/node-exporter-dashboard.json "$STACK_ROOT_DIR/grafana/config/dashboards/homelab/node-exporter-dashboard.json"
fi
if [ ! -f "$STACK_ROOT_DIR/grafana/config/datasources/datasources.yml" ]; then
  cp configs/grafana-provisioning/datasources/datasources.yml "$STACK_ROOT_DIR/grafana/config/datasources/datasources.yml"
else
  echo -e "${YELLOW}datasources.yml already exists in $STACK_ROOT_DIR/grafana/config/datasources. Skipping copy.${NC}"
fi
# Set permissions for Grafana directories
chown -R 472:472 "$STACK_ROOT_DIR/grafana"
chmod -R 755 "$STACK_ROOT_DIR/grafana"
