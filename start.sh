#!/bin/bash
#
# Elastic Stack 9.x - Linux Docker Swarm Startup Script
# This script sets up and deploys the complete Elastic Stack
#
# Usage: ./start.sh [--force]
#   --force    Skip confirmation prompts
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env file if it exists
if [ -f .env ]; then
    echo -e "${BLUE}Loading configuration from .env file...${NC}"
    set -a
    source .env
    set +a
fi

# Set defaults
export ELASTIC_VERSION=${ELASTIC_VERSION:-9.2.4}
export ELASTICSEARCH_USERNAME=${ELASTICSEARCH_USERNAME:-elastic}
export ELASTICSEARCH_PASSWORD=${ELASTICSEARCH_PASSWORD:-changeme}
export ELASTICSEARCH_HOST=${ELASTICSEARCH_HOST:-localhost}
export KIBANA_HOST=${KIBANA_HOST:-localhost}
export DISCOVERY_TYPE=${DISCOVERY_TYPE:-single-node}
export KIBANA_SYSTEM_PASSWORD=${KIBANA_SYSTEM_PASSWORD:-changeme}
export KIBANA_ENCRYPTION_KEY=${KIBANA_ENCRYPTION_KEY:-aV67MfXdown18LNlA9Jt3kWuaC2xYz99}

echo ""
echo -e "${BLUE}=========================================="
echo "  Elastic Stack ${ELASTIC_VERSION} - Startup Script"
echo -e "==========================================${NC}"
echo ""

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Not running as root. Some operations may require sudo.${NC}"
        return 1
    fi
    return 0
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}ERROR: Docker is not installed.${NC}"
        echo "Please install Docker first: https://docs.docker.com/engine/install/"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Docker installed"

    # Check Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}ERROR: Docker daemon is not running.${NC}"
        echo "Please start Docker: sudo systemctl start docker"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} Docker daemon running"

    # Check Docker version
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Docker version: ${DOCKER_VERSION}"
}

# Function to configure system settings
configure_system() {
    echo ""
    echo -e "${BLUE}Configuring system settings...${NC}"

    # Check vm.max_map_count
    CURRENT_MAP_COUNT=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo "0")
    REQUIRED_MAP_COUNT=262144

    if [ "$CURRENT_MAP_COUNT" -lt "$REQUIRED_MAP_COUNT" ]; then
        echo -e "  ${YELLOW}vm.max_map_count is ${CURRENT_MAP_COUNT}, needs ${REQUIRED_MAP_COUNT}${NC}"

        if check_root; then
            sysctl -w vm.max_map_count=262144
            echo -e "  ${GREEN}✓${NC} vm.max_map_count set to 262144"
        else
            echo -e "  ${YELLOW}Attempting with sudo...${NC}"
            sudo sysctl -w vm.max_map_count=262144
            echo -e "  ${GREEN}✓${NC} vm.max_map_count set to 262144"
        fi

        # Make it persistent
        if [ -w /etc/sysctl.conf ] || check_root; then
            if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
                echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null
                echo -e "  ${GREEN}✓${NC} Added to /etc/sysctl.conf for persistence"
            fi
        fi
    else
        echo -e "  ${GREEN}✓${NC} vm.max_map_count is ${CURRENT_MAP_COUNT} (OK)"
    fi
}

# Function to initialize Docker Swarm
init_swarm() {
    echo ""
    echo -e "${BLUE}Checking Docker Swarm...${NC}"

    if docker node ls &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker Swarm is already initialized"
        NODE_COUNT=$(docker node ls --format '{{.ID}}' | wc -l)
        echo -e "  ${GREEN}✓${NC} Swarm has ${NODE_COUNT} node(s)"
    else
        echo -e "  ${YELLOW}Docker Swarm not initialized. Initializing...${NC}"

        # Get the default IP address
        DEFAULT_IP=$(hostname -I | awk '{print $1}')

        if docker swarm init --advertise-addr "$DEFAULT_IP" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Docker Swarm initialized with IP: ${DEFAULT_IP}"
        else
            # Try without specifying IP
            if docker swarm init 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Docker Swarm initialized"
            else
                echo -e "${RED}ERROR: Failed to initialize Docker Swarm.${NC}"
                echo "Try manually: docker swarm init --advertise-addr <your-ip>"
                exit 1
            fi
        fi
    fi
}

# Function to deploy the stack
deploy_stack() {
    echo ""
    echo -e "${BLUE}Deploying Elastic Stack...${NC}"

    # Check if stack already exists
    if docker stack ls | grep -q "^elastic "; then
        echo -e "  ${YELLOW}Stack 'elastic' already exists. Updating...${NC}"
    fi

    # Deploy
    docker stack deploy --compose-file docker-compose.yml elastic

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Stack deployment initiated"
    else
        echo -e "${RED}ERROR: Failed to deploy stack.${NC}"
        exit 1
    fi
}

# Function to wait for services
wait_for_services() {
    echo ""
    echo -e "${BLUE}Waiting for services to start...${NC}"
    echo "  This may take 2-5 minutes on first run..."
    echo ""

    # Wait for Elasticsearch
    echo -n "  Waiting for Elasticsearch"
    COUNTER=0
    MAX_WAIT=120
    while [ $COUNTER -lt $MAX_WAIT ]; do
        if curl -sf -u "elastic:${ELASTICSEARCH_PASSWORD}" "http://localhost:9200/_cluster/health" &> /dev/null; then
            echo -e " ${GREEN}✓${NC}"
            break
        fi
        echo -n "."
        sleep 5
        COUNTER=$((COUNTER + 5))
    done

    if [ $COUNTER -ge $MAX_WAIT ]; then
        echo -e " ${YELLOW}(timeout - may still be starting)${NC}"
    fi

    # Wait for Kibana
    echo -n "  Waiting for Kibana"
    COUNTER=0
    MAX_WAIT=180
    while [ $COUNTER -lt $MAX_WAIT ]; do
        if curl -sf "http://localhost:5601/api/status" &> /dev/null; then
            echo -e " ${GREEN}✓${NC}"
            break
        fi
        echo -n "."
        sleep 5
        COUNTER=$((COUNTER + 5))
    done

    if [ $COUNTER -ge $MAX_WAIT ]; then
        echo -e " ${YELLOW}(timeout - may still be starting)${NC}"
    fi
}

# Function to show status
show_status() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "  Deployment Status"
    echo -e "==========================================${NC}"
    echo ""

    # Show services
    echo -e "${BLUE}Services:${NC}"
    docker stack services elastic
    echo ""

    # Show Elasticsearch health
    echo -e "${BLUE}Elasticsearch Health:${NC}"
    curl -sf -u "elastic:${ELASTICSEARCH_PASSWORD}" "http://localhost:9200/_cluster/health?pretty" 2>/dev/null || echo "  (not ready yet)"
    echo ""

    # Access information
    echo -e "${GREEN}=========================================="
    echo "  Access Information"
    echo -e "==========================================${NC}"
    echo ""
    echo -e "  ${BLUE}Kibana:${NC}         http://localhost:5601"
    echo -e "  ${BLUE}Elasticsearch:${NC}  http://localhost:9200"
    echo -e "  ${BLUE}Logstash GELF:${NC}  udp://localhost:12201"
    echo ""
    echo -e "  ${BLUE}Username:${NC}       ${ELASTICSEARCH_USERNAME}"
    echo -e "  ${BLUE}Password:${NC}       ${ELASTICSEARCH_PASSWORD}"
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo "  docker stack services elastic"
    echo "  docker stack ps elastic --no-trunc"
    echo "  docker service logs elastic_elasticsearch -f"
    echo "  docker service logs elastic_kibana -f"
    echo ""
}

# Function to show security warning
show_security_warning() {
    if [ "${ELASTICSEARCH_PASSWORD}" = "changeme" ]; then
        echo ""
        echo -e "${YELLOW}=========================================="
        echo "  SECURITY WARNING"
        echo -e "==========================================${NC}"
        echo -e "${YELLOW}  Using default password 'changeme'${NC}"
        echo -e "${YELLOW}  For production, create a .env file:${NC}"
        echo "    cp .env.example .env"
        echo "    # Edit .env with secure passwords"
        echo ""
    fi
}

# Main execution
main() {
    # Check for --force flag
    FORCE=false
    if [ "$1" = "--force" ]; then
        FORCE=true
    fi

    # Show configuration
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Elastic Version:    ${ELASTIC_VERSION}"
    echo "  Discovery Type:     ${DISCOVERY_TYPE}"
    echo "  Elasticsearch Host: ${ELASTICSEARCH_HOST}"
    echo "  Kibana Host:        ${KIBANA_HOST}"
    echo ""

    # Confirmation
    if [ "$FORCE" = false ]; then
        read -p "Continue with deployment? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Deployment cancelled."
            exit 0
        fi
    fi

    # Run setup steps
    check_prerequisites
    configure_system
    init_swarm
    deploy_stack
    show_security_warning
    wait_for_services
    show_status

    echo -e "${GREEN}Deployment complete!${NC}"
}

# Run main function
main "$@"
