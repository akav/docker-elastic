@echo off
REM Remove Elastic Beats from Docker Swarm (Windows)
REM Usage: removeBeats.bat [filebeat|metricbeat|auditbeat|packetbeat|all]

setlocal

if "%1"=="" goto usage
if "%1"=="help" goto usage
if "%1"=="-h" goto usage
if "%1"=="--help" goto usage

echo ==========================================
echo Removing Beats
echo ==========================================

if "%1"=="filebeat" goto remove_filebeat
if "%1"=="metricbeat" goto remove_metricbeat
if "%1"=="auditbeat" goto remove_auditbeat
if "%1"=="packetbeat" goto remove_packetbeat
if "%1"=="all" goto remove_all
goto usage

:remove_filebeat
echo Removing Filebeat...
docker stack rm filebeat
goto end

:remove_metricbeat
echo Removing Metricbeat...
docker stack rm metricbeat
goto end

:remove_auditbeat
echo Removing Auditbeat...
docker stack rm auditbeat
goto end

:remove_packetbeat
echo Removing Packetbeat...
docker stack rm packetbeat
goto end

:remove_all
echo Removing all beats...
docker stack rm filebeat 2>nul
docker stack rm metricbeat 2>nul
docker stack rm auditbeat 2>nul
docker stack rm packetbeat 2>nul
echo All beats removed!
goto end

:usage
echo.
echo Usage: removeBeats.bat [beat-name]
echo.
echo Available options:
echo   filebeat    - Remove Filebeat
echo   metricbeat  - Remove Metricbeat
echo   auditbeat   - Remove Auditbeat
echo   packetbeat  - Remove Packetbeat
echo   all         - Remove all beats
echo.
exit /b 0

:end
echo.
echo Waiting for services to be removed...
timeout /t 5 /nobreak >nul
echo Done!
echo.

endlocal
