# HomeLab Monitoring Stack

# Docker Monitoring Stack

This repository contains a Docker Compose setup for a complete monitoring stack using Prometheus, Grafana, Loki, Promtail, Node Exporter, and cAdvisor. This stack provides comprehensive monitoring for both the host system and all Docker containers.

## Components

- **Prometheus**: Time series database for storing metrics
- **Grafana**: Visualization and dashboarding tool
- **Loki**: Log aggregation system
- **Promtail**: Log collector for Loki
- **Node Exporter**: Collects host system metrics
- **cAdvisor**: Collects container metrics

## Prerequisites

- Ubuntu 24.04 or compatible Linux distribution
- Docker and Docker Compose installed
- Sufficient disk space for metrics and logs storage

## Directory Structure

The stack uses a centralized directory structure under `/opt/monitoring`:

```
/opt/monitoring/
├── docker-compose.yml
├── .env
├── grafana/
│   ├── data/
│   └── provisioning/
│       ├── dashboards/
│       │   ├── cadvisor/
│       │   └── node-exporter/
│       └── datasources/
├── prometheus/
│   ├── config/
│   └── data/
├── loki/
│   ├── config/
│   └── data/
└── promtail/
    └── config/
```

## Required Permissions

Proper permissions are critical for this monitoring stack to function correctly:

### Directory Permissions

1. **Prometheus Directories**:
   ```bash
   sudo chown -R 65534:65534 /opt/monitoring/prometheus/data
   sudo chown -R 65534:65534 /opt/monitoring/prometheus/config
   sudo chmod -R 755 /opt/monitoring/prometheus
   ```
   - Prometheus runs as user 65534 (nobody) and needs write access to its directories

2. **Grafana Directories**:
   ```bash
   sudo chown -R 472:472 /opt/monitoring/grafana
   sudo chmod -R 755 /opt/monitoring/grafana
   ```
   - Grafana runs as user 472 and needs write access to its data directory

3. **Loki Directories**:
   ```bash
   sudo mkdir -p /opt/monitoring/loki/data
   sudo mkdir -p /opt/monitoring/loki/config
   sudo chown -R 10001:10001 /opt/monitoring/loki/data
   sudo chown -R 10001:10001 /opt/monitoring/loki/config
   sudo chmod -R 755 /opt/monitoring/loki
   ```
   - Loki runs as user 10001 and needs write access to its directories

4. **Promtail Directories**:
   ```bash
   sudo mkdir -p /opt/monitoring/promtail/config
   sudo chmod -R 755 /opt/monitoring/promtail
   ```

5. **Environment File**:
   ```bash
   sudo chmod 600 /opt/monitoring/.env
   ```
   - Restrict access to .env file since it contains credentials

### Docker Socket Access

For cAdvisor to monitor Docker containers:
```bash
sudo chmod 666 /var/run/docker.sock
```
OR add the user running Docker Compose to the docker group:
```bash
sudo usermod -aG docker $USER
```

### Log Access

Promtail needs access to system and container logs:
```bash
sudo chmod -R 755 /var/log
sudo chmod -R 755 /var/lib/docker/containers
```

## Network Configuration

The stack creates a custom Docker network named `custom_monitoring_network`. All services are connected to this network, allowing them to communicate using container names as hostnames.

## Port Assignments

- Grafana: `3000`
- Prometheus: `9090`
- Loki: `3100`
- Node Exporter: `9100`
- cAdvisor: `8181`

## Environment Variables

Sensitive information like credentials is stored in the `.env` file:

```properties
# Global settings
CONTAINER_NAME_PREFIX=mon--

# Grafana credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=secure_password_here

# Add other environment variables as needed
```

## Installation

### Scripted mode

Run the included init script:

```bash
./stack_init.sh
```

### Manual mode

1. Create the necessary directories and set permissions:
   ```bash
   # Create directories
   sudo mkdir -p /opt/monitoring/{grafana,prometheus,loki,promtail}/{config,data}
   sudo mkdir -p /opt/monitoring/grafana/provisioning/{datasources,dashboards}
   sudo mkdir -p /opt/monitoring/grafana/provisioning/dashboards/{node-exporter,cadvisor}
   
   # Set permissions
   sudo chown -R 65534:65534 /opt/monitoring/prometheus/data
   sudo chown -R 65534:65534 /opt/monitoring/prometheus/config
   sudo chown -R 472:472 /opt/monitoring/grafana
   sudo chown -R 10001:10001 /opt/monitoring/loki/data
   sudo chown -R 10001:10001 /opt/monitoring/loki/config
   sudo chmod -R 755 /opt/monitoring
   sudo chmod 600 /opt/monitoring/.env
   ```

2. Copy configuration files to their respective directories.

3. Deploy the stack:
   ```bash
   cd /opt/monitoring
   docker compose up -d
   ```

## Troubleshooting

### Common Issues

1. **Prometheus fails to start with permission errors**:
   - Check ownership of the Prometheus data directory
   - Ensure the container is running as user 65534
   
2. **Grafana shows "no data" for dashboards**:
   - Verify Prometheus is running and collecting data
   - Check Grafana datasource configuration
   - Ensure the time range in Grafana is appropriate

3. **Promtail cannot read container logs**:
   - Check permissions on `/var/lib/docker/containers`
   - Verify Docker is logging to the JSON file driver

4. **cAdvisor shows no container metrics**:
   - Check if cAdvisor has access to the Docker socket
   - Verify that the cAdvisor container is running

## Maintenance

### Backup

To backup your monitoring configuration and data:

```bash
# Backup Prometheus data
sudo tar -czf prometheus_data_backup.tar.gz -C /opt/monitoring prometheus

# Backup Grafana data
sudo tar -czf grafana_data_backup.tar.gz -C /opt/monitoring grafana

# Backup configuration files
sudo tar -czf monitoring_config_backup.tar.gz /opt/monitoring/*.yml /opt/monitoring/*.json /opt/monitoring/.env
```

### Updating

To update the monitoring stack:

```bash
cd /opt/monitoring
docker compose pull
docker compose down
docker compose up -d
```

## Security Considerations

- Change default credentials in the `.env` file
- Consider implementing HTTPS for Grafana and Prometheus
- Restrict access to the monitoring stack using a reverse proxy or firewall rules
- Regularly update all components to the latest versions

## Prometheus Node Exporter

### Installation

```bash
./install_node_exporter.sh                    # Standard installation
./install_node_exporter.sh --temp             # Installation with temperature monitoring
./install_node_exporter.sh --proxmox          # Installation with Proxmox monitoring
./install_node_exporter.sh --temp --proxmox   # Both temperature and Proxmox monitoring
```

### Uninstall

```bash
./uninstall_node_exporter.sh
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [cAdvisor Documentation](https://github.com/google/cadvisor)
