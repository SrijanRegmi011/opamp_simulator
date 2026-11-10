@echo off
echo ===============================================================
echo   Op-Amp Virtual Lab: Launching in Google Chrome
echo   Backend: PostgreSQL 18 (opamp_vlab)
echo   URL: http://localhost:8080
echo ===============================================================

tasklist /FI "IMAGENAME eq python.exe" 2>NUL | find /I /N "python.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [INFO] Backend server already running.
) else (
    echo [INFO] Starting backend server...
    start "OpAmp Backend" /B python backend/server.py
    timeout /t 2 /nobreak >nul
)

echo [INFO] Opening in Google Chrome...
start "" "http://localhost:8080"
