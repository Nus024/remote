@echo off
chcp 65001 >nul
cls
title Wireless Gesture Controller PC & HP
color 0B

echo ======================================================================
echo           PENGONTROL NIRKABEL HP KE LAYAR PC / LAPTOP
echo ======================================================================
echo.
echo [1] Menutup proses server lama (jika ada)...
powershell -Command "Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*server.py*' -or $_.CommandLine -like '*http.server 8000*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo [2] Menjalankan Wireless Gesture Server (server.py)...
start /b "" python server.py >nul 2>&1

timeout /t 2 >nul

echo [3] Membuka Dokumen Reader di Browser PC Anda...
start http://localhost:8000/index.html

echo.
echo ======================================================================
echo                       CARA MENGHUBUNGKAN HP:
echo ======================================================================
echo.
echo  1. Pastikan HP dan PC terhubung ke jaringan Wi-Fi lokal yang sama.
echo.
echo  2. Buka browser di HP Anda (Chrome disarankan), ketik alamat:
echo.
echo        http://192.168.1.49:8000/remote.html
echo.
echo  3. Tiga Metode Pengendalian dari HP:
echo     a. Sentuhan Layar HP:
echo        - Snap Shorts (1 Video) : Tepat 1 video YouTube Shorts / TikTok
echo        - Gulir Halus           : Gulir kontinu YouTube biasa, web & dokumen
echo     b. Ujung Jari Telunjuk    : Angkat sedikit untuk naik, tekuk untuk turun
echo     c. Lirikan Mata           : Poni HP = Naik, Navbar bawah HP = Turun
echo.
echo  4. Target Pengendalian:
echo     - "Seluruh Windows OS" (YouTube, TikTok, Word, PDF, Browser lain)
echo     - "Reader Web PC" (Dokumen Reader index.html)
echo.
echo  --------------------------------------------------------------------
echo  TIPS KAMERA CHROME HP (Jika kamera selfie tidak muncul):
echo  - Di Chrome HP buka: chrome://flags
echo  - Cari: Insecure origins treated as secure
echo  - Masukkan: http://192.168.1.49:8000 lalu pilih Enabled, klik Relaunch.
echo ======================================================================
echo   Server aktif di latar belakang (Port 8000).
echo   Tekan sembarang tombol di jendela ini jika ingin menghentikan server.
echo ======================================================================
pause >nul

echo Menghentikan server...
powershell -Command "Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*server.py*' } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo Selesai.
