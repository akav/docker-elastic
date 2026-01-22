#!/bin/bash
#
# Elastic Stack 9.x - Linux Docker Swarm Stop Script
# This script stops and optionally removes the Elastic Stack
#
# Usage: ./stop.sh [--volumes] [--force]
#   --volumes  Also remove data volumes (WARNING: destroys data)
#   --force    Skip confirmation prompts
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
REMOVE_VOLUMES=false
FORCE=false

for arg in "$@"; do
    case $arg in
        --volumes)
            REMOVE_VOLUMES=true
            ;;
        --force)
            FORCE=true
            ;;
    esac
done

echo ""
echo -e "${BLUE}=========================================="
echo "  Elastic Stack - Stop Script"
echo -e "==========================================${NC}"
echo ""

# Warning for volume removal
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${RED}WARNING: --volumes flag set. This will DESTROY ALL DATA!${NC}"
    echo ""
fi

# Confirmation
if [ "$FORCE" = false ]; then
    if [ "$REMOVE_VOLUMES" = true ]; then
        read -p "Are you sure you want to stop and DELETE ALL DATA? (yes/N): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Operation cancelled."
            exit 0
        fi
    else
        read -p "Stop the Elastic Stack? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Operation cancelled."
            exit 0
        fi
    fi
fi

# Remove stacks
echo -e "${BLUE}Removing stacks...${NC}"

echo "  Removing elastic stack..."
docker stack rm elastic 2>/dev/null || true

echo "  Removing filebeat stack..."
docker stack rm filebeat 2>/dev/null || true

echo "  Removing metricbeat stack..."
docker stack rm metricbeat 2>/dev/null || true

echo "  Removing auditbeat stack..."
docker stack rm auditbeat 2>/dev/null || true

echo "  Removing packetbeat stack..."
docker stack rm packetbeat 2>/dev/null || true

# Wait for services to be removed
echo ""
echo -e "${BLUE}Waiting for services to stop...${NC}"
sleep 10

# Check if services are still running
COUNTER=0
MAX_WAIT=60
while [ $COUNTER -lt $MAX_WAIT ]; do
    SERVICES=$(docker service ls --format '{{.Name}}' 2>/dev/null | grep -E "^(elastic_|filebeat_|metricbeat_|auditbeat_|packetbeat_)" || true)
    if [ -z "$SERVICES" ]; then
        echo -e "  ${GREEN}✓${NC} All services stopped"
        break
    fi
    echo "  Still waiting for services to stop..."
    sleep 5
    COUNTER=$((COUNTER + 5))
done

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" = true ]; then
    echo ""
    echo -e "${BLUE}Removing volumes...${NC}"

    # Wait a bit more for containers to fully stop
    sleep 5

    docker volume rm elastic_elasticsearch 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed elastic_elasticsearch" || true
    docker volume rm elastic_kibana 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed elastic_kibana" || true
    docker volume rm filebeat_filebeat 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed filebeat_filebeat" || true
    docker volume rm metricbeat_metricbeat 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed metricbeat_metricbeat" || true
    docker volume rm auditbeat_auditbeat 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed auditbeat_auditbeat" || true
    docker volume rm packetbeat_packetbeat 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed packetbeat_packetbeat" || true
fi

# Remove networks
echo ""
echo -e "${BLUE}Removing networks...${NC}"
docker network rm elastic_elastic 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed elastic_elastic" || true
docker network rm elastic 2>/dev/null && echo -e "  ${GREEN}✓${NC} Removed elastic" || true

echo ""
echo -e "${GREEN}=========================================="
echo "  Elastic Stack Stopped"
echo -e "==========================================${NC}"
echo ""

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${YELLOW}All data has been removed.${NC}"
else
    echo "Data volumes preserved. Use --volumes to remove them."
fi
echo ""
