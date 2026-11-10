@echo off
echo Stopping Op-Amp Backend Server...
taskkill /F /IM pythonw.exe 2>nul
taskkill /F /FI "WINDOWTITLE eq Op-Amp Virtual Lab Backend Server*" 2>nul
echo Backend server stopped.
timeout /t 2 /nobreak >nul
