# Learning Beats Autodiscover

Learn how to use [Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-autodiscover-hints.html) and [Metricbeat](https://www.elastic.co/guide/en/beats/metricbeat/current/configuration-autodiscover.html) hint-based autodiscover features for Docker containers.

## Versions

This example has been tested with:
- Elasticsearch 9.2.4
- Kibana 9.2.4
- Filebeat 9.2.4
- Metricbeat 9.2.4

## Prerequisites

Use the provided Vagrantfile to create 3x VMs:
- **node1** and **node2** _(Docker Swarm cluster)_: Running Elasticsearch, Kibana, and Logstash
  - Follow the instructions in [../README.md](../README.md) to deploy the Elastic Stack
- **node3**: Running Filebeat and Metricbeat in swarm mode
  - See instructions in [../README.md](../README.md) for deploying Beats

The examples below should be run on **node3**.

## How Autodiscover Works

Beats autodiscover uses Docker labels to automatically configure log and metric collection for containers. When a container starts with specific `co.elastic.*` labels, Beats will:

1. Detect the new container
2. Read the labels to determine which modules to enable
3. Start collecting logs/metrics according to the configuration

## Example: Apache2 Module

Ensure nothing is listening on port 80, then run:

```bash
docker container run --rm \
  --label co.elastic.logs/module=apache \
  --label co.elastic.logs/fileset.stdout=access \
  --label co.elastic.logs/fileset.stderr=error \
  --label co.elastic.metrics/module=apache \
  --label co.elastic.metrics/metricsets=status \
  --label co.elastic.metrics/hosts='${data.host}:${data.port}' \
  --detach=true \
  --name apache \
  --publish 80:80 \
  httpd:latest
```

### Label Explanation

| Label | Description |
|-------|-------------|
| `co.elastic.logs/module=apache` | Use the Apache Filebeat module |
| `co.elastic.logs/fileset.stdout=access` | Parse stdout as Apache access logs |
| `co.elastic.logs/fileset.stderr=error` | Parse stderr as Apache error logs |
| `co.elastic.metrics/module=apache` | Use the Apache Metricbeat module |
| `co.elastic.metrics/metricsets=status` | Collect Apache status metrics |
| `co.elastic.metrics/hosts` | Dynamic host:port for metrics endpoint |

## Example: NGINX Module

Ensure nothing is listening on port 80, then run:

```bash
docker container run --rm \
  --label co.elastic.logs/module=nginx \
  --label co.elastic.logs/fileset.stdout=access \
  --label co.elastic.logs/fileset.stderr=error \
  --label co.elastic.metrics/module=nginx \
  --label co.elastic.metrics/metricsets=stubstatus \
  --label co.elastic.metrics/hosts='${data.host}:${data.port}' \
  --detach=true \
  --name nginx \
  --publish 80:80 \
  nginx:latest
```

> **Note**: For NGINX metrics to work, you need to enable the stub_status module. See the NGINX documentation for details.

## Example: MySQL Module

```bash
docker container run --rm \
  --label co.elastic.logs/module=mysql \
  --label co.elastic.logs/fileset.stdout=slowlog \
  --label co.elastic.logs/fileset.stderr=error \
  --label co.elastic.metrics/module=mysql \
  --label co.elastic.metrics/metricsets=status \
  --label co.elastic.metrics/hosts='root:password@tcp(${data.host}:${data.port})/' \
  --env MYSQL_ROOT_PASSWORD=password \
  --detach=true \
  --name mysql \
  --publish 3306:3306 \
  mysql:8
```

## Example: Redis Module

```bash
docker container run --rm \
  --label co.elastic.logs/module=redis \
  --label co.elastic.logs/fileset.stdout=log \
  --label co.elastic.metrics/module=redis \
  --label co.elastic.metrics/metricsets=info,keyspace \
  --label co.elastic.metrics/hosts='${data.host}:${data.port}' \
  --detach=true \
  --name redis \
  --publish 6379:6379 \
  redis:latest
```

## Testing

1. **Generate traffic**: Browse to `http://node3` for Apache/NGINX examples
2. **Generate errors**: Browse to non-existent pages like `http://node3/hello/world`
3. **View in Kibana**:
   - Navigate to **Analytics > Discover**
   - Select `filebeat-*` index for logs
   - Select `metricbeat-*` index for metrics
4. **View Dashboards**:
   - Navigate to **Analytics > Dashboard**
   - Search for "Apache" or "Nginx" dashboards

## Multiline Logs

For containers that produce multiline logs (like Java stack traces), add:

```bash
--label co.elastic.logs/multiline.pattern='^[[:space:]]' \
--label co.elastic.logs/multiline.negate=false \
--label co.elastic.logs/multiline.match=after
```

## Custom Processors

Add custom processors via labels:

```bash
--label co.elastic.logs/processors.add_fields.target='' \
--label co.elastic.logs/processors.add_fields.fields.environment=production
```

## Disabling Autodiscover for Specific Containers

To exclude a container from autodiscover:

```bash
--label co.elastic.logs/enabled=false \
--label co.elastic.metrics/enabled=false
```

## Troubleshooting

### Logs not appearing in Kibana

1. Check that Filebeat is running: `docker service ps filebeat_filebeat`
2. Check Filebeat logs: `docker service logs filebeat_filebeat`
3. Verify the container has the correct labels: `docker inspect <container_name>`

### Metrics not appearing

1. Check that Metricbeat is running: `docker service ps metricbeat_metricbeat`
2. Verify the application exposes metrics (e.g., NGINX stub_status enabled)
3. Check network connectivity between Metricbeat and the application

### Common Label Mistakes

- Missing quotes around label values with special characters
- Incorrect module names (check Elastic documentation for exact names)
- `${data.host}` not resolving (ensure container is on same network)

## References

- [Filebeat Autodiscover](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-autodiscover.html)
- [Metricbeat Autodiscover](https://www.elastic.co/guide/en/beats/metricbeat/current/configuration-autodiscover.html)
- [Hints-based Autodiscover](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-autodiscover-hints.html)
- [Available Filebeat Modules](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html)
- [Available Metricbeat Modules](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-modules.html)
