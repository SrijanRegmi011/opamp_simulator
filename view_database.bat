@echo off
title Op-Amp Virtual Lab - Database Inspector
echo ===============================================================
echo   Fetching Live Data from PostgreSQL (opamp_vlab)...
echo ===============================================================
python backend/view_db.py
echo.
pause
