@echo off
REM Deploy Elastic Stack 9.x to Docker Swarm (Windows)
REM Usage: deployStack.bat
REM
REM Configuration options:
REM   1. Create a .env file (copy from .env.example)
REM   2. Set environment variables before running
REM   3. Use defaults (for development only)

setlocal enabledelayedexpansion

REM Load .env file if it exists
if exist .env (
    echo Loading configuration from .env file...
    for /f "usebackq tokens=1,* delims==" %%a in (".env") do (
        REM Skip comments and empty lines
        set "line=%%a"
        if not "!line:~0,1!"=="#" (
            if not "%%a"=="" (
                set "%%a=%%b"
            )
        )
    )
)

REM Configuration - Set defaults if not already set
if not defined ELASTIC_VERSION set "ELASTIC_VERSION=9.2.4"
if not defined ELASTICSEARCH_USERNAME set "ELASTICSEARCH_USERNAME=elastic"
if not defined ELASTICSEARCH_PASSWORD set "ELASTICSEARCH_PASSWORD=changeme"
if not defined ELASTICSEARCH_HOST set "ELASTICSEARCH_HOST=localhost"
if not defined KIBANA_HOST set "KIBANA_HOST=localhost"
REM Discovery type: single-node (default for development) or multi-node (for cluster)
if not defined DISCOVERY_TYPE set "DISCOVERY_TYPE=single-node"
REM Password for kibana_system user (required in Elastic 8+)
if not defined KIBANA_SYSTEM_PASSWORD set "KIBANA_SYSTEM_PASSWORD=changeme"
REM Use a simpler encryption key without special characters for Windows compatibility
if not defined KIBANA_ENCRYPTION_KEY set "KIBANA_ENCRYPTION_KEY=aV67MfXdown18LNlA9Jt3kWuaC2xYz99"

REM Security warning for default password
if "!ELASTICSEARCH_PASSWORD!"=="changeme" (
    echo.
    echo WARNING: Using default password 'changeme'
    echo WARNING: For production, set ELASTICSEARCH_PASSWORD or create a .env file
    echo.
)

echo ==========================================
echo Deploying Elastic Stack !ELASTIC_VERSION!
echo ==========================================
echo Elasticsearch Host: !ELASTICSEARCH_HOST!
echo Kibana Host: !KIBANA_HOST!
echo Discovery Type: !DISCOVERY_TYPE!
echo ==========================================

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker Desktop first.
    exit /b 1
)

REM Check if Swarm is initialized
docker node ls >nul 2>&1
if errorlevel 1 (
    echo Docker Swarm is not initialized. Initializing...
    docker swarm init
    if errorlevel 1 (
        echo ERROR: Failed to initialize Docker Swarm.
        echo If you have multiple network interfaces, try:
        echo   docker swarm init --advertise-addr ^<your-ip^>
        exit /b 1
    )
)

REM Deploy the stack (network will be created automatically)
echo Deploying Elastic Stack...
docker stack deploy --compose-file docker-compose.yml elastic

if errorlevel 1 (
    echo ERROR: Failed to deploy stack.
    exit /b 1
)

echo.
echo ==========================================
echo Deployment initiated!
echo ==========================================
echo.
echo Wait for services to start (this may take 3-5 minutes)...
echo.
echo Check status with:
echo   docker stack services elastic
echo   docker stack ps elastic --no-trunc
echo.
echo Verify Elasticsearch health:
echo   curl -u !ELASTICSEARCH_USERNAME!:!ELASTICSEARCH_PASSWORD! http://!ELASTICSEARCH_HOST!:9200/_cluster/health?pretty
echo.
echo Access Kibana at: http://!KIBANA_HOST!:5601
echo   Username: !ELASTICSEARCH_USERNAME!
echo   Password: (as configured)
echo.
echo Elasticsearch API: http://!ELASTICSEARCH_HOST!:9200
echo.

endlocal
