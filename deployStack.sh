#!/bin/bash

# Deploy Elastic Stack 9.x to Docker Swarm
# Usage: ./deployStack.sh
#
# Configuration options:
#   1. Create a .env file (copy from .env.example)
#   2. Set environment variables before running
#   3. Use defaults (for development only)

set -e

# Load .env file if it exists
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    set -a
    source .env
    set +a
fi

# Configuration - Override these with environment variables as needed
export ELASTIC_VERSION=${ELASTIC_VERSION:-9.2.4}
export ELASTICSEARCH_USERNAME=${ELASTICSEARCH_USERNAME:-elastic}
export ELASTICSEARCH_PASSWORD=${ELASTICSEARCH_PASSWORD:-changeme}
export ELASTICSEARCH_HOST=${ELASTICSEARCH_HOST:-localhost}
export KIBANA_HOST=${KIBANA_HOST:-localhost}
# Discovery type: single-node (default for development) or multi-node (for cluster)
export DISCOVERY_TYPE=${DISCOVERY_TYPE:-single-node}

# Password for kibana_system user (required in Elastic 8+ - cannot use elastic superuser)
export KIBANA_SYSTEM_PASSWORD=${KIBANA_SYSTEM_PASSWORD:-changeme}

# Optional: Kibana encryption key (32 characters minimum, no special characters)
export KIBANA_ENCRYPTION_KEY=${KIBANA_ENCRYPTION_KEY:-"aV67MfXdown18LNlA9Jt3kWuaC2xYz99"}

# Security warning for default password
if [ "${ELASTICSEARCH_PASSWORD}" = "changeme" ]; then
    echo ""
    echo "⚠️  WARNING: Using default password 'changeme'"
    echo "⚠️  For production, set ELASTICSEARCH_PASSWORD or create a .env file"
    echo ""
fi

echo "=========================================="
echo "Deploying Elastic Stack ${ELASTIC_VERSION}"
echo "=========================================="
echo "Elasticsearch Host: ${ELASTICSEARCH_HOST}"
echo "Kibana Host: ${KIBANA_HOST}"
echo "Discovery Type: ${DISCOVERY_TYPE}"
echo "=========================================="

# Deploy the stack (network will be created automatically)
echo "Deploying Elastic Stack..."
docker stack deploy --compose-file docker-compose.yml elastic

echo ""
echo "=========================================="
echo "Deployment initiated!"
echo "=========================================="
echo ""
echo "Wait for services to start (this may take 3-5 minutes)..."
echo ""
echo "Check status with:"
echo "  docker stack services elastic"
echo "  docker stack ps elastic --no-trunc"
echo ""
echo "Verify Elasticsearch health:"
echo "  curl -u ${ELASTICSEARCH_USERNAME}:${ELASTICSEARCH_PASSWORD} http://${ELASTICSEARCH_HOST}:9200/_cluster/health?pretty"
echo ""
echo "Access Kibana at: http://${KIBANA_HOST}:5601"
echo "  Username: ${ELASTICSEARCH_USERNAME}"
echo "  Password: (as configured)"
echo ""
echo "Elasticsearch API: http://${ELASTICSEARCH_HOST}:9200"
echo ""
