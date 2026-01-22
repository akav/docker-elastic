# Auditbeat Manual Deployment

Docker Swarm now supports capabilities (since Docker 19.03+), but for maximum compatibility or when running outside of Swarm mode, you can deploy Auditbeat manually using the instructions below.

## Prerequisites

- Docker 19.03+ installed
- Elasticsearch cluster running and accessible
- Kibana running (optional, for dashboards)

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

Run Auditbeat:

```bash
docker container run \
    --rm --detach \
    --hostname=${NODE_NAME}-auditbeat \
    --name=auditbeat \
    --user=root \
    --volume=$PWD/elk/beats/auditbeat/config/auditbeat.yml:/usr/share/auditbeat/auditbeat.yml:ro \
    --volume=/var/log:/var/log:ro \
    --volume=/etc/passwd:/hostfs/etc/passwd:ro \
    --volume=/etc/group:/hostfs/etc/group:ro \
    --cap-add=AUDIT_READ \
    --cap-add=AUDIT_CONTROL \
    --pid=host \
    --env ELASTICSEARCH_USERNAME=${ELASTICSEARCH_USERNAME} \
    --env ELASTICSEARCH_PASSWORD=${ELASTICSEARCH_PASSWORD} \
    --env ELASTICSEARCH_HOST=${ELASTICSEARCH_HOST} \
    --env KIBANA_HOST=${KIBANA_HOST} \
    docker.elastic.co/beats/auditbeat:${ELASTIC_VERSION} \
    --strict.perms=false
```

## Verifying the Deployment

Check if Auditbeat is running:

```bash
docker logs auditbeat
```

Verify data in Elasticsearch:

```bash
curl -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} \
    "http://${ELASTICSEARCH_HOST}:9200/_cat/indices/auditbeat-*?v"
```

## Stopping Auditbeat

```bash
docker container stop auditbeat
```

## Notes

- **Kernel Requirements**: The `AUDIT_READ` capability requires kernel version 3.16 or later. Older distributions like CentOS 7 (kernel 3.10) may not support all features.
- **Ubuntu/Debian**: Ensure auditd is installed: `sudo apt-get install -y auditd audispd-plugins`
- **Security**: In Elastic 9.x, security is enabled by default. For SSL/TLS connections, add the appropriate certificate configuration.

## Docker Swarm Deployment

For Docker Swarm deployments (Docker 19.03+), use the compose file instead:

```bash
export ELASTIC_VERSION=9.2.4
export ELASTICSEARCH_HOST=node1
export KIBANA_HOST=node1
export ELASTICSEARCH_USERNAME=elastic
export ELASTICSEARCH_PASSWORD=changeme

docker stack deploy --compose-file auditbeat-docker-compose.yml auditbeat
```
