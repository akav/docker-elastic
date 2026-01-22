@echo off
REM Remove Elastic Stack from Docker Swarm (Windows)
REM Usage: removeStack.bat [--volumes]

setlocal

echo ==========================================
echo Removing Elastic Stack
echo ==========================================

REM Remove the stack
echo Removing elastic stack...
docker stack rm elastic

echo.
echo Waiting for services to be removed...
timeout /t 10 /nobreak >nul

REM Check if volumes should be removed
if "%1"=="--volumes" (
    echo.
    echo Removing volumes...
    docker volume rm elastic_elasticsearch 2>nul
    docker volume rm elastic_kibana 2>nul
    docker volume rm filebeat_filebeat 2>nul
    docker volume rm metricbeat_metricbeat 2>nul
    docker volume rm auditbeat_auditbeat 2>nul
    docker volume rm packetbeat_packetbeat 2>nul
    echo Volumes removed
)

echo.
echo ==========================================
echo Stack removed successfully!
echo ==========================================
echo.
echo Note: The 'elastic' network was not removed.
echo To remove it manually: docker network rm elastic
echo.
echo To also remove data volumes, run: removeStack.bat --volumes
echo.

endlocal
