# Elastic Stack on Docker Swarm

Deploy the [Elastic Stack](https://www.elastic.co/elastic-stack) (Elasticsearch, Kibana, Logstash, and Beats) on Docker Swarm for centralized logging, metrics collection, and observability.

**Version: 9.2.4** (Elastic Stack 9.x)

<p align="center">
  <img src="./pics/elastic-products.PNG" alt="Elastic products" style="width: 400px;"/>
</p>

## Features

- Elasticsearch cluster with automatic scaling
- Kibana for visualization and dashboards
- Logstash for log processing (GELF input)
- Filebeat for container and system log collection
- Metricbeat for system and Docker metrics
- Auditbeat for security auditing
- Packetbeat for network monitoring
- Health checks on all services
- Resource limits and reservations

## Architecture

| High Level Design | Components | Notes |
|-------------------|------------|-------|
| <img src="./pics/elastic-stack-arch.png" alt="Elastic Stack" style="width: 400px;"/> | 2x Elasticsearch nodes, 1x Kibana, 1x Logstash | Beats ship logs/metrics directly to Elasticsearch |
| <img src="./pics/basic_logstash_pipeline.png" alt="Logstash Pipeline" style="width: 400px;"/> | GELF log driver for containerized applications | Optional: Use Logstash for advanced log processing |

## Prerequisites

### System Requirements

- Docker 19.03+ with Swarm mode enabled
- At least 2 nodes for Elasticsearch cluster (recommended: 10GB RAM each)
- `vm.max_map_count` set to 262144 on all Elasticsearch nodes

```bash
# Set vm.max_map_count (required for Elasticsearch)
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
```

### Development Environment (Vagrant)

Use the provided Vagrantfile to create a 3-node cluster:

```bash
# Install required Vagrant plugins
vagrant plugin install vagrant-hostmanager

# Start the VMs
vagrant up
```

This creates:
- **node1** (192.168.99.101): Docker Swarm manager, Elasticsearch master
- **node2** (192.168.99.102): Docker Swarm worker, Elasticsearch data
- **node3** (192.168.99.103): Separate Swarm for Beats testing

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/shazChaudhry/docker-elastic.git
cd docker-elastic
```

### 2. Configure Environment (Optional)

Copy the example environment file and customize:

```bash
cp .env.example .env
# Edit .env with your settings
```

### 3. Deploy the Elastic Stack

**Linux/macOS:**
```bash
./deployStack.sh
```

**Windows:**
```cmd
deployStack.bat
```

**Manual deployment:**
```bash
export ELASTIC_VERSION=9.2.4
export ELASTICSEARCH_USERNAME=elastic
export ELASTICSEARCH_PASSWORD=changeme
export ELASTICSEARCH_HOST=node1
export INITIAL_MASTER_NODES=node1

docker network create --driver overlay --attachable elastic
docker stack deploy --compose-file docker-compose.yml elastic
```

### 4. Verify Deployment

Wait 3-5 minutes for services to start, then verify:

```bash
# Check service status
docker stack services elastic
docker stack ps elastic --no-trunc

# Check Elasticsearch health
curl -u elastic:changeme http://node1:9200/_cluster/health?pretty
```

### 5. Access Kibana

Open your browser to `http://localhost:5601` (or `http://your-host:5601`)

- **Username**: `elastic`
- **Password**: `changeme` (or your configured password)

> **Note**: Kibana runs on port 5601. Elasticsearch is available on port 9200.

## Deploy Beats

Deploy Filebeat and Metricbeat to collect logs and metrics from your Docker Swarm nodes.

### Quick Deploy (All Beats)

**Windows:**
```cmd
deployBeats.bat all
```

**Linux/macOS:**
```bash
# Deploy individual beats
docker stack deploy --compose-file filebeat-docker-compose.yml filebeat
docker stack deploy --compose-file metricbeat-docker-compose.yml metricbeat
```

### Environment Setup (Manual)

```bash
export ELASTIC_VERSION=9.2.4
export ELASTICSEARCH_USERNAME=elastic
export ELASTICSEARCH_PASSWORD=changeme
export ELASTICSEARCH_HOST=node1
export KIBANA_HOST=node1

docker network create --driver overlay --attachable elastic
```

### Filebeat (Container Logs)

```bash
# Linux/macOS
docker stack deploy --compose-file filebeat-docker-compose.yml filebeat

# Windows
deployBeats.bat filebeat
```

Filebeat collects:
- Container stdout/stderr logs from `/var/lib/docker/containers/*/*.log`
- System logs (syslog, auth)
- Auditd logs (if installed)

### Metricbeat (System Metrics)

```bash
docker stack deploy --compose-file metricbeat-docker-compose.yml metricbeat
```

Metricbeat collects:
- System metrics (CPU, memory, disk, network)
- Docker container metrics
- Process information

### Auditbeat (Security Auditing)

```bash
docker stack deploy --compose-file auditbeat-docker-compose.yml auditbeat
```

See [auditbeat-README.md](auditbeat-README.md) for manual deployment options.

### Packetbeat (Network Monitoring)

> **Note**: Packetbeat has limited functionality in Docker Swarm mode. See [packetbeat-README.md](packetbeat-README.md) for details.

```bash
docker stack deploy --compose-file packetbeat-docker-compose.yml packetbeat
```

### Verify Beats Data

```bash
# Check indices
curl -u elastic:changeme http://node1:9200/_cat/indices/*beat*?v
```

## Testing

### Test with Jenkins Container

```bash
# Start Jenkins
docker container run -d --rm --name jenkins -p 8080:8080 jenkins/jenkins:lts

# View logs in Kibana under Discover > filebeat-*
```

### Test GELF Logging via Logstash

```bash
export LOGSTASH_HOST=node1

# Start container with GELF log driver
docker container run -d --rm --name jenkins \
  -p 8080:8080 \
  --log-driver=gelf \
  --log-opt gelf-address=udp://${LOGSTASH_HOST}:12201 \
  jenkins/jenkins:lts

# View logs in Kibana under Discover > logstash-*
```

### Simple GELF Test

```bash
docker container run --rm -it \
  --log-driver=gelf \
  --log-opt gelf-address=udp://${LOGSTASH_HOST}:12201 \
  alpine ping -c 10 8.8.8.8
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ELASTIC_VERSION` | `9.2.4` | Elastic Stack version |
| `ELASTICSEARCH_USERNAME` | `elastic` | Elasticsearch username |
| `ELASTICSEARCH_PASSWORD` | `changeme` | Elasticsearch password |
| `ELASTICSEARCH_HOST` | `node1` | Elasticsearch host |
| `KIBANA_HOST` | `node1` | Kibana host |
| `INITIAL_MASTER_NODES` | `node1` | Initial Elasticsearch master nodes |

### Security Notes

- **Change default passwords** before deploying to production
- Security is enabled by default in Elastic 9.x
- For SSL/TLS setup, see the SSL configuration sections in beat config files
- Consider using Docker secrets for sensitive credentials

## Removing the Stack

**Linux/macOS:**
```bash
# Remove stack (keeps data volumes)
./removeStack.sh

# Remove stack and data volumes
./removeStack.sh --volumes
```

**Windows:**
```cmd
REM Remove stack (keeps data volumes)
removeStack.bat

REM Remove stack and data volumes
removeStack.bat --volumes

REM Remove beats
removeBeats.bat all
```

**Remove network:**
```bash
docker network rm elastic
```

## Troubleshooting

### Common Issues

1. **Elasticsearch won't start**: Check `vm.max_map_count` is set to 262144
2. **Connection refused**: Wait for services to fully start (3-5 minutes)
3. **Out of memory**: Increase VM memory or adjust heap settings in docker-compose.yml
4. **Beats not sending data**: Verify network connectivity and credentials

### Useful Commands

```bash
# View service logs
docker service logs elastic_elasticsearch
docker service logs elastic_kibana
docker service logs filebeat_filebeat

# Check cluster health
curl -u elastic:changeme http://node1:9200/_cluster/health?pretty

# List indices
curl -u elastic:changeme http://node1:9200/_cat/indices?v

# Check nodes
curl -u elastic:changeme http://node1:9200/_cat/nodes?v
```

## Examples

See the [examples](./examples/) directory for additional tutorials:
- [Filebeat with NGINX logs](./examples/learn_filebeat.md)
- [Autodiscover with Docker labels](./examples/learn_autodiscover.md)

## References

- [Elastic Documentation](https://www.elastic.co/guide/index.html)
- [Elasticsearch Examples](https://github.com/elastic/examples)
- [Elastic Stack Sizing Guide](https://www.elastic.co/guide/en/elasticsearch/guide/current/hardware.html)
- [Docker Logging Best Practices](https://docs.docker.com/config/containers/logging/)
