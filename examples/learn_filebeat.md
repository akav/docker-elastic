# Learning Filebeat with Elastic Stack

The examples here are for learning purposes only and demonstrate how to start Filebeat and visualize data in Kibana.

## Versions

This example has been tested with:
- Elasticsearch 9.2.4
- Kibana 9.2.4
- Filebeat 9.2.4

## Prerequisites

Use the provided Vagrantfile to create 3x VMs:
- **node1** and **node2** _(Docker Swarm cluster)_ are for running Elasticsearch, Kibana and Logstash in swarm mode
  - Follow the instructions in [../README.md](../README.md) to deploy the Elastic Stack
- **node3** is where Filebeat examples below will be running

### Important Notes for Elastic 9.x

Starting from Elastic 8.x, security is enabled by default. You will need to:
1. Generate and configure SSL certificates
2. Use the enrollment token or configure authentication properly
3. Ensure network connectivity between Filebeat and Elasticsearch/Kibana

## Common Data Formats - NGINX Logs

This example demonstrates how to ingest, analyze and visualize NGINX access logs using the Elastic Stack (Elasticsearch, Filebeat, and Kibana). The sample NGINX access logs use the default NGINX combined log format.

We use the Filebeat [NGINX module](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-module-nginx.html) per Elastic Stack best practices.

### Step 1: Download Sample NGINX Logs

Assuming you are on **node3**, execute the commands below:

```bash
mkdir -p nginx_logs && cd nginx_logs
curl -O https://raw.githubusercontent.com/elastic/examples/master/Common%20Data%20Formats/nginx_logs/nginx_logs
```

### Step 2: Setup Kibana Dashboards (One-time)

Before running Filebeat for the first time, set up the Kibana dashboards:

```bash
docker run --rm \
  --name filebeat-setup \
  --network host \
  docker.elastic.co/beats/filebeat:9.2.4 \
  setup \
  -E setup.kibana.host='node1:5601' \
  -E setup.kibana.username=elastic \
  -E setup.kibana.password=changeme \
  -E output.elasticsearch.hosts='["node1:9200"]' \
  -E output.elasticsearch.username=elastic \
  -E output.elasticsearch.password=changeme
```

### Step 3: Run Filebeat with NGINX Module

```bash
docker run --rm \
  --name filebeat \
  --network host \
  --volume filebeat-data:/usr/share/filebeat/data \
  --volume $PWD:/tmp:ro \
  docker.elastic.co/beats/filebeat:9.2.4 \
  filebeat -e \
  --modules nginx \
  -M "nginx.access.var.paths=[/tmp/nginx_logs]" \
  -E output.elasticsearch.hosts='["node1:9200"]' \
  -E output.elasticsearch.username=elastic \
  -E output.elasticsearch.password=changeme
```

### Configuration Notes

| Parameter | Description |
|-----------|-------------|
| `--network host` | Uses host networking for easy access to Elasticsearch |
| `--volume filebeat-data:/usr/share/filebeat/data` | Persists Filebeat registry data |
| `--volume $PWD:/tmp:ro` | Mounts log files as read-only |
| `--modules nginx` | Enables the NGINX module |
| `-M "nginx.access.var.paths=[...]"` | Specifies the path to NGINX access logs |

### Step 4: Visualize Data in Kibana

1. Open Kibana at `http://node1:5601`
2. Login with:
   - Username: `elastic`
   - Password: `changeme`
3. Navigate to **Analytics > Dashboard**
4. Search for **[Filebeat Nginx] Overview**
5. Adjust the time range to match the sample data:
   - From: `2015-05-16 00:00:00.000`
   - To: `2015-06-05 23:59:59.999`

## Alternative: Using a Configuration File

For more complex setups, create a `filebeat.yml` configuration file:

```yaml
filebeat.modules:
  - module: nginx
    access:
      enabled: true
      var.paths: ["/tmp/nginx_logs"]
    error:
      enabled: false

output.elasticsearch:
  hosts: ["node1:9200"]
  username: "elastic"
  password: "changeme"

setup.kibana:
  host: "node1:5601"
  username: "elastic"
  password: "changeme"
```

Then run Filebeat with the config file:

```bash
docker run --rm \
  --name filebeat \
  --network host \
  --volume $PWD/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro \
  --volume filebeat-data:/usr/share/filebeat/data \
  --volume $PWD:/tmp:ro \
  docker.elastic.co/beats/filebeat:9.2.4 \
  filebeat -e
```

## Secure Setup (SSL/TLS)

For production environments with SSL/TLS enabled:

```bash
docker run --rm \
  --name filebeat \
  --network host \
  --volume filebeat-data:/usr/share/filebeat/data \
  --volume $PWD:/tmp:ro \
  --volume /path/to/certs:/certs:ro \
  docker.elastic.co/beats/filebeat:9.2.4 \
  filebeat -e \
  --modules nginx \
  -M "nginx.access.var.paths=[/tmp/nginx_logs]" \
  -E output.elasticsearch.hosts='["https://node1:9200"]' \
  -E output.elasticsearch.username=elastic \
  -E output.elasticsearch.password=changeme \
  -E output.elasticsearch.ssl.certificate_authorities=["/certs/ca.crt"]
```

## Troubleshooting

### Common Issues

1. **Connection refused**: Ensure Elasticsearch is running and accessible from node3
2. **Authentication failed**: Verify username/password are correct
3. **Certificate errors**: For SSL setups, ensure CA certificate is properly mounted
4. **No data in Kibana**: Check the time range matches the log timestamps

### Useful Commands

Check Filebeat logs:
```bash
docker logs filebeat
```

Test Elasticsearch connectivity:
```bash
curl -u elastic:changeme http://node1:9200/_cluster/health?pretty
```

List Filebeat indices:
```bash
curl -u elastic:changeme http://node1:9200/_cat/indices/filebeat-*?v
```

## References

- [Filebeat Documentation](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
- [Filebeat NGINX Module](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-module-nginx.html)
- [Running Filebeat on Docker](https://www.elastic.co/guide/en/beats/filebeat/current/running-on-docker.html)
- [Elastic Examples on GitHub](https://github.com/elastic/examples)
