@echo off
echo === Spring Boot Log Management Setup ===
echo.

REM Create logs directory
echo Creating logs directory...
if not exist logs mkdir logs
echo [OK] Logs directory created
echo.

REM Start Docker Compose stack
echo Starting Docker Compose stack...
docker-compose up -d
echo.

REM Wait for services to start
echo Waiting for services to start...
timeout /t 10 /nobreak >nul
echo.

REM Check status
echo === Service Status ===
docker-compose ps
echo.

REM Verify Loki
echo === Verifying Loki ===
curl -s http://localhost:3100/ready >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Loki is ready
) else (
    echo [FAIL] Loki is not ready
)
echo.

REM Verify Grafana
echo === Verifying Grafana ===
curl -s http://localhost:3000/api/health | findstr "ok" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Grafana is healthy
) else (
    echo [FAIL] Grafana is not healthy
)
echo.

REM Generate sample logs
echo === Generating Sample Logs ===
python generate-logs.py batch 50
echo.

REM Wait for logs to be ingested
echo Waiting for log ingestion...
timeout /t 3 /nobreak >nul
echo.

REM Verify logs were sent to Loki
echo === Verifying Log Ingestion ===
curl -s http://localhost:3100/loki/api/v1/label/job/values | findstr "spring-boot" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Logs are in Loki
) else (
    echo [FAIL] Logs not found in Loki
)
echo.

echo === Setup Complete! ===
echo.
echo Access Grafana at: http://localhost:3000
echo Username: admin
echo Password: admin
echo.
echo Try this query in Grafana Explore: {job="spring-boot"}
echo.
pause
