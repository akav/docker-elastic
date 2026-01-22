#!/bin/bash

# Remove Elastic Stack from Docker Swarm
# Usage: ./removeStack.sh [--volumes]

set -e

echo "=========================================="
echo "Removing Elastic Stack"
echo "=========================================="

# Remove the stack
echo "Removing elastic stack..."
docker stack rm elastic

echo ""
echo "Waiting for services to be removed..."
sleep 10

# Check if volumes should be removed
if [ "$1" == "--volumes" ]; then
    echo ""
    echo "Removing volumes..."
    docker volume rm elastic_elasticsearch elastic_kibana 2>/dev/null || true
    docker volume rm filebeat_filebeat 2>/dev/null || true
    docker volume rm metricbeat_metricbeat 2>/dev/null || true
    docker volume rm auditbeat_auditbeat 2>/dev/null || true
    docker volume rm packetbeat_packetbeat 2>/dev/null || true
    echo "Volumes removed"
fi

echo ""
echo "=========================================="
echo "Stack removed successfully!"
echo "=========================================="
echo ""
echo "Note: The 'elastic' network was not removed."
echo "To remove it manually: docker network rm elastic"
echo ""
echo "To also remove data volumes, run: ./removeStack.sh --volumes"
echo ""
