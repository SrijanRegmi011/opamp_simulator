@echo off
title Op-Amp Virtual Lab - Database Connection Status
echo ===============================================================
echo     Checking PostgreSQL Database Connection Status
echo ===============================================================
echo.
echo [1] Checking PostgreSQL 18 Service (Port 5432):
"D:\PostgreSQL\18\bin\pg_isready.exe" -p 5432 -d opamp_vlab
echo.
echo [2] Querying Backend REST API Health Status:
curl -s http://localhost:8080/api/health
echo.
echo.
echo ===============================================================
pause
