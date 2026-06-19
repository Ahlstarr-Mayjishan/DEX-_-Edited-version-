@echo off
title DEX++ Stop Local Services
echo Stopping DEX++ Helper and Potassium Decompiler...
taskkill /IM DEX_Helper.exe /F >nul 2>nul
taskkill /IM Decompiler.exe /F >nul 2>nul
echo Local ports 8080 and 56535 have been released.
timeout /t 2 >nul
