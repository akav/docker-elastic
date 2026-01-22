# Packetbeat Manual Deployment

> **Note**: Packetbeat has limited functionality in Docker Swarm mode due to network isolation requirements. For best results, deploy Packetbeat using host network mode outside of Swarm, or use the manual deployment method below.

## Prerequisites

- Docker 19.03+ installed
- Elasticsearch cluster running and accessible
- Kibana running (optional, for dashboards)
- Host network access for packet capture

## Manual Deployment

Set the required environment variables:

```bash
export ELASTIC_VERSION=9.2.4
export ELASTICSEARCH_USERNAME=elastic
export ELASTICSEARCH_PASSWORD=changeme
export ELASTICSEARCH_HOST=node1
export KIBANA_HOST=node1
export NODE_NAME=$(hostname)
```

Run Packetbeat with host networking:

```bash
docker container run \
    --rm --detach \
    --hostname=${NODE_NAME}-packetbeat \
    --name=packetbeat \
    --user=root \
    --volume=$PWD/elk/beats/packetbeat/config/packetbeat.yml:/usr/share/packetbeat/packetbeat.yml:ro \
    --volume=/var/run/docker.sock:/var/run/docker.sock:ro \
    --cap-add=NET_RAW \
    --cap-add=NET_ADMIN \
    --network=host \
    --env ELASTICSEARCH_USERNAME=${ELASTICSEARCH_USERNAME} \
    --env ELASTICSEARCH_PASSWORD=${ELASTICSEARCH_PASSWORD} \
    --env ELASTICSEARCH_HOST=${ELASTICSEARCH_HOST} \
    --env KIBANA_HOST=${KIBANA_HOST} \
    docker.elastic.co/beats/packetbeat:${ELASTIC_VERSION} \
    --strict.perms=false
```

## Verifying the Deployment

Check if Packetbeat is running:

```bash
docker logs packetbeat
```

Verify data in Elasticsearch:

```bash
curl -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} \
    "http://${ELASTICSEARCH_HOST}:9200/_cat/indices/packetbeat-*?v"
```

## Stopping Packetbeat

```bash
docker container stop packetbeat
```

## Supported Protocols

Packetbeat 9.x supports monitoring the following protocols:

- **ICMP** - Ping and traceroute
- **DNS** - Domain name resolution
- **HTTP** - Web traffic (ports 80, 8080, 5000, 8000, 9200)
- **TLS** - Encrypted connections (ports 443, 8443)
- **MySQL** - Database queries (port 3306)
- **PostgreSQL** - Database queries (port 5432)
- **Redis** - Cache operations (port 6379)
- **MongoDB** - Database operations (port 27017)

## Docker Swarm Limitations

Packetbeat requires `--network=host` to capture packets at the host level. In Docker Swarm mode, this creates issues because:

1. Overlay networks isolate container traffic
2. Host network mode bypasses Swarm's load balancing
3. Packet capture may only see local container traffic

For production Swarm deployments, consider:
- Running Packetbeat directly on the host (not in a container)
- Using Filebeat with network logs instead
- Deploying Packetbeat outside of Swarm management

## Notes

- **Security**: In Elastic 9.x, security is enabled by default. For SSL/TLS connections to Elasticsearch, add certificate configuration to the packetbeat.yml file.
- **Performance**: Packetbeat can be resource-intensive. Monitor CPU and memory usage, especially on high-traffic nodes.
