@echo off
REM Deploy Elastic Beats to Docker Swarm (Windows)
REM Usage: deployBeats.bat [filebeat|metricbeat|auditbeat|packetbeat|all]
REM
REM Examples:
REM   deployBeats.bat filebeat     - Deploy only Filebeat
REM   deployBeats.bat all          - Deploy all beats
REM   deployBeats.bat              - Shows usage

setlocal enabledelayedexpansion

REM Load .env file if it exists
if exist .env (
    echo Loading configuration from .env file...
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
        set "line=%%a"
        if not "!line:~0,1!"=="#" (
            if not "%%a"=="" (
                set "%%a=%%b"
            )
        )
    )
)

REM Configuration - Set defaults if not already set
if not defined ELASTIC_VERSION set ELASTIC_VERSION=9.2.4
if not defined ELASTICSEARCH_USERNAME set ELASTICSEARCH_USERNAME=elastic
if not defined ELASTICSEARCH_PASSWORD set ELASTICSEARCH_PASSWORD=changeme
if not defined ELASTICSEARCH_HOST set ELASTICSEARCH_HOST=node1
if not defined KIBANA_HOST set KIBANA_HOST=node1

REM Check arguments
if "%1"=="" goto usage
if "%1"=="help" goto usage
if "%1"=="-h" goto usage
if "%1"=="--help" goto usage

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running. Please start Docker Desktop first.
    exit /b 1
)

REM Check if elastic network exists
docker network ls | findstr /C:"elastic" >nul 2>&1
if errorlevel 1 (
    echo Creating elastic overlay network...
    docker network create --driver overlay --attachable elastic
)

echo ==========================================
echo Deploying Beats - Elastic Stack %ELASTIC_VERSION%
echo ==========================================

if "%1"=="filebeat" goto deploy_filebeat
if "%1"=="metricbeat" goto deploy_metricbeat
if "%1"=="auditbeat" goto deploy_auditbeat
if "%1"=="packetbeat" goto deploy_packetbeat
if "%1"=="all" goto deploy_all
goto usage

:deploy_filebeat
echo Deploying Filebeat...
docker stack deploy --compose-file filebeat-docker-compose.yml filebeat
if errorlevel 1 (
    echo ERROR: Failed to deploy Filebeat
    exit /b 1
)
echo Filebeat deployed successfully!
goto end

:deploy_metricbeat
echo Deploying Metricbeat...
docker stack deploy --compose-file metricbeat-docker-compose.yml metricbeat
if errorlevel 1 (
    echo ERROR: Failed to deploy Metricbeat
    exit /b 1
)
echo Metricbeat deployed successfully!
goto end

:deploy_auditbeat
echo Deploying Auditbeat...
docker stack deploy --compose-file auditbeat-docker-compose.yml auditbeat
if errorlevel 1 (
    echo ERROR: Failed to deploy Auditbeat
    exit /b 1
)
echo Auditbeat deployed successfully!
goto end

:deploy_packetbeat
echo.
echo NOTE: Packetbeat has limited functionality in Docker Swarm mode.
echo See packetbeat-README.md for details.
echo.
echo Deploying Packetbeat...
docker stack deploy --compose-file packetbeat-docker-compose.yml packetbeat
if errorlevel 1 (
    echo ERROR: Failed to deploy Packetbeat
    exit /b 1
)
echo Packetbeat deployed successfully!
goto end

:deploy_all
echo Deploying all beats...
echo.
call :deploy_filebeat
call :deploy_metricbeat
call :deploy_auditbeat
call :deploy_packetbeat
echo.
echo All beats deployed!
goto end

:usage
echo.
echo Usage: deployBeats.bat [beat-name]
echo.
echo Available beats:
echo   filebeat    - Deploy Filebeat (container and system logs)
echo   metricbeat  - Deploy Metricbeat (system and Docker metrics)
echo   auditbeat   - Deploy Auditbeat (security auditing)
echo   packetbeat  - Deploy Packetbeat (network monitoring)
echo   all         - Deploy all beats
echo.
echo Examples:
echo   deployBeats.bat filebeat
echo   deployBeats.bat all
echo.
exit /b 0

:end
echo.
echo Check status with:
echo   docker stack services filebeat
echo   docker stack services metricbeat
echo.
echo Verify data in Elasticsearch:
echo   curl -u %ELASTICSEARCH_USERNAME%:%ELASTICSEARCH_PASSWORD% http://%ELASTICSEARCH_HOST%:9200/_cat/indices/*beat*?v
echo.

endlocal
