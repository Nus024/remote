@echo off
chcp 65001 >nul
cls
title Universal PC Remote Controller
color 0B

echo ======================================================================
echo           UNIVERSAL REMOTE CONTROLLER PC DARI HP
echo ======================================================================
echo.
echo [1] Menutup proses server lama (jika ada)...
powershell -Command "Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*server.py*' -or $_.CommandLine -like '*http.server 8000*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo [2] Menjalankan Server Remote PC (server.py)...
start /b "" python server.py >nul 2>&1

timeout /t 2 >nul

for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.254*' -and $_.IPAddress -ne '127.0.0.1' }).IPAddress | Select-Object -First 1"') do set "PC_IP=%%i"
if "%PC_IP%"=="" set "PC_IP=192.168.1.49"

echo.
echo ======================================================================
echo                       CARA MENGHUBUNGKAN HP:
echo ======================================================================
echo.
echo  1. Pastikan HP dan PC terhubung ke Wi-Fi / Hotspot yang sama.
echo.
echo  2. Buka browser di HP Anda (Chrome / Safari), ketik alamat:
echo.
echo        http://%PC_IP%:8000
echo.
echo  3. Fitur Kontrol Remote HP:
echo     - Snap Shorts (1 Video) : 1 Usapan = Tepat 1 video Shorts / TikTok
echo     - Gulir Halus           : Gulir kontinu YouTube biasa, PDF, Word
echo     - Mode Mouse Trackpad   : Kursor, Klik Kiri, Klik Kanan ^& Roda Scroll
echo     - Play / Pause          : Jeda atau putar video seketika
echo     - Audio PC              : Tombol Volume Naik (+), Turun (-), dan Mute
echo     - Mode Kamera           : Kontrol via Ujung Jari Telunjuk atau Lirikan
echo ======================================================================
echo   Server aktif di latar belakang (Port 8000).
echo   Tekan sembarang tombol di jendela ini jika ingin menghentikan server.
echo ======================================================================
pause >nul

echo Menghentikan server...
powershell -Command "Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*server.py*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo Selesai.

