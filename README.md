# Docker Compose Configurations

This repository contains a collection of pre-configured Docker Compose setups for various self-hosted applications and services. Each configuration is organized in its own directory with the necessary files to quickly deploy these services.

## Available Configurations

### 1. Authentik

A modern Identity Provider focused on flexibility and versatility.

- **Category**: `prod`
- **Directory**: `/authentik`
- **Services**:
  - PostgreSQL database
  - Redis cache
  - Authentik server
  - Authentik worker
- **Default ports**:
  - HTTP: 9000
  - HTTPS: 9443

### 2. Grafana Monitoring Stack

A complete monitoring solution with metrics, logs, and visualization.

- **Category**: `prod`
- **Directory**: `/grafana-monitoring-stack`
- **Services**:
  - Prometheus (metrics database)
  - Loki (log aggregation)
  - Promtail (log collector)
  - Grafana (visualization platform)
  - Node Exporter (host metrics)
  - cAdvisor (container metrics)
- **Default ports**:
  - Grafana: 3000
  - Prometheus: 9090
  - Loki: 3100
  - Node Exporter: 9100
  - cAdvisor: 8181

## Usage Instructions

### General Setup

1. Navigate to the desired service directory
2. Create a `.env` file with the required environment variables
3. Run `docker-compose up -d` to start the services
