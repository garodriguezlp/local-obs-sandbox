@echo off
echo Resetting Spring Boot Log Stack...
echo.

REM Stop containers and remove volumes
echo Stopping Docker containers...
docker-compose down -v

REM Remove logs
if exist logs (
    echo Removing logs directory...
    rmdir /s /q logs
)

echo.
echo [OK] Stack reset complete
echo.
echo Starting fresh stack...
echo.

REM Start fresh using the up script
if exist up.bat (
    call up.bat
) else (
    REM Inline version if up.bat doesn't exist
    mkdir logs
    docker-compose up -d
    timeout /t 8 /nobreak >nul
    python generate-logs.py batch 50
    echo.
    echo Fresh stack is ready!
    echo Grafana UI: http://localhost:3000
)
