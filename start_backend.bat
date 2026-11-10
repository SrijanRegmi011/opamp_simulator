@echo off
echo ===============================================================
echo     Op-Amp Virtual Lab: Starting REST API Backend Server
echo ===============================================================

where dart >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Dart detected. Launching Dart backend server...
    dart run backend/bin/server.dart
) else (
    echo [INFO] Launching Python backend server...
    python backend/server.py
)
pause
