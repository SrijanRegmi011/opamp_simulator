@echo off
title Op-Amp Virtual Lab Backend Server
echo ===============================================================
echo     Op-Amp Virtual Lab: PostgreSQL Backend Server Live
echo ===============================================================
echo.
echo  [DATABASE] PostgreSQL 18 (opamp_vlab on port 5432)
echo  [PC URL]   http://localhost:8080
echo  [PHONE IP] http://192.168.0.100:8080
echo.
echo  Keep this window open while using the mobile app or browser!
echo ===============================================================
echo.
python backend/server.py
pause
