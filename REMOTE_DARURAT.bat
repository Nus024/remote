@echo off
title REMOTE DARURAT - KONTROL PC DARI HP
chcp 65001 >nul
color 0B
cls
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create((Get-Content -LiteralPath '%~f0' | Select-Object -Skip 9 | Out-String)))"
pause
exit /b %ERRORLEVEL%

# =========================================================================
# REMOTE PC DARURAT (1-FILE ZERO-INSTALL)
# Berjalan 100% Native di Windows 10 & 11 tanpa install Python atau software lain
# =========================================================================

$PORT = 8000
$ErrorActionPreference = 'SilentlyContinue'
trap { continue }

# 1. Hentikan proses lama di port 8000 jika ada (supaya tidak bentrok)
try {
    $netstat = netstat -ano | Select-String ":$PORT\s"
    foreach ($line in $netstat) {
        $tokens = ($line -replace '\s+', ' ').Trim().Split(' ')
        if ($tokens.Count -ge 5 -and $tokens[3] -eq "LISTENING") {
            $p = [int]$tokens[-1]
            if ($p -gt 0 -and $p -ne $PID) {
                Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch {}

# 2. Compile Win32 Helper (Keyboard, Mouse, Volume)
$csharp = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class Win32Remote {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public const byte VK_SPACE = 0x20;
    public const byte VK_PRIOR = 0x21;
    public const byte VK_NEXT = 0x22;
    public const byte VK_UP = 0x26;
    public const byte VK_DOWN = 0x28;
    public const byte VK_K = 0x4B;
    public const byte VK_VOLUME_MUTE = 0xAD;
    public const byte VK_VOLUME_DOWN = 0xAE;
    public const byte VK_VOLUME_UP = 0xAF;
    public const byte VK_MEDIA_PLAY_PAUSE = 0xB3;

    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint MOUSEEVENTF_WHEEL = 0x0800;

    public static void PressKey(byte vk) {
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        keybd_event(vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static void ScrollMouse(int delta) {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta, UIntPtr.Zero);
    }

    public static string GetActiveTitle() {
        IntPtr h = GetForegroundWindow();
        if (h == IntPtr.Zero) return "";
        StringBuilder sb = new StringBuilder(512);
        GetWindowText(h, sb, sb.Capacity);
        return sb.ToString();
    }

    public static void PlayPause() {
        string t = GetActiveTitle().ToLower();
        if (t.Contains("youtube")) {
            PressKey(VK_K);
        } else {
            PressKey(VK_MEDIA_PLAY_PAUSE);
        }
    }
}
"@
Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue

# 3. Deteksi IP Lokal Wi-Fi Laptop Panitia
function Get-LocalIPAddress {
    try {
        $s = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork, [System.Net.Sockets.SocketType]::Dgram, [System.Net.Sockets.ProtocolType]::Udp)
        $s.Connect("8.8.8.8", 80)
        $ip = $s.LocalEndPoint.Address.ToString()
        $s.Close()
        if ($ip -and $ip -ne "127.0.0.1") { return $ip }
    } catch {}

    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*", "Ethernet*", "WLAN*" -ErrorAction SilentlyContinue |
               Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } |
               Select-Object -First 1).IPAddress
        if ($ip) { return $ip }
    } catch {}

    return "127.0.0.1"
}

$LAN_IP = Get-LocalIPAddress

# 4. Embedded HTML (Decompress Gzip Base64)
$EMBEDDED_HTML_GZ_B64 = "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"

function Get-RemoteHtmlBytes {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptDir) {
        $localFile = Join-Path $scriptDir "remote.html"
        if (Test-Path $localFile) {
            return [System.IO.File]::ReadAllBytes($localFile)
        }
    }
    try {
        $inBytes = [Convert]::FromBase64String($EMBEDDED_HTML_GZ_B64)
        $msIn = New-Object System.IO.MemoryStream(,$inBytes)
        $gz = New-Object System.IO.Compression.GZipStream($msIn, [System.IO.Compression.CompressionMode]::Decompress)
        $msOut = New-Object System.IO.MemoryStream
        $gz.CopyTo($msOut)
        $gz.Close()
        return $msOut.ToArray()
    } catch {
        return [System.Text.Encoding]::UTF8.GetBytes("<h1>Remote Siap.</h1>")
    }
}

$remoteHtmlBytes = Get-RemoteHtmlBytes

# 5. Tampilkan Banner Status & Petunjuk Ramah Pengguna
Clear-Host
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "             REMOTE PC DARURAT (1-FILE ZERO-INSTALL)                    " -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  IP LAPTOP PANITIA :  $LAN_IP  (Port: $PORT)" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  LANGKAH MENGHUBUNGKAN DARI HP ANDA:" -ForegroundColor White
Write-Host "  1. Pastikan HP & laptop ini terhubung ke Wi-Fi / Hotspot yang sama." -ForegroundColor Gray
Write-Host "  2. Di HP Anda:" -ForegroundColor Gray
Write-Host "     - Jika remote sudah terbuka di HP : Klik ikon [Gear] -> Masukkan IP: $LAN_IP" -ForegroundColor Yellow
Write-Host "     - ATAU buka browser HP (Chrome/Safari) : http://${LAN_IP}:${PORT}" -ForegroundColor Yellow
Write-Host "       (Halaman remote akan langsung muncul di layar HP!)" -ForegroundColor Gray
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  Fungsi Tombol di Layar HP:" -ForegroundColor White
Write-Host "  - Tombol Next / Prev : Maju / Mundur slide (PowerPoint, PDF, Word, Canva)" -ForegroundColor Gray
Write-Host "  - Tombol Play/Pause  : Jeda / Putar video (YouTube, TikTok, VLC, Media)" -ForegroundColor Gray
Write-Host "  - Vol -, Vol +, Mute : Atur volume master suara laptop" -ForegroundColor Gray
Write-Host "  - Usap Layar (Swipe) : Navigasi video Shorts/TikTok (1 usap = 1 video)" -ForegroundColor Gray
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  STATUS: Siap menerima koneksi dari HP... (Tekan Ctrl+C untuk keluar)" -ForegroundColor Green
Write-Host ""

# 6. Inisialisasi TCP HTTP Listener
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $PORT)
try {
    $listener.Start()
} catch {
    Write-Host "Gagal membuka port $PORT. Error: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

$wheelAccumulator = 0.0

# 7. Loop Penanganan Request HTTP dari HP (Crash-Proof & Auto-Recover)
while ($true) {
    try {
        if ($listener.Pending()) {
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $stream.ReadTimeout = 2000
                $stream.WriteTimeout = 2000

                $buffer = New-Object byte[] 8192
                $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $rawRequest = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
                    $firstLine = ($rawRequest -split "`r?`n")[0]
                    $parts = $firstLine.Split(" ")
                    $method = if ($parts.Length -gt 0) { $parts[0].ToUpper() } else { "" }
                    $rawPath = if ($parts.Length -gt 1) { $parts[1] } else { "/" }
                    $path = ($rawPath.Split("?"))[0]

                    # A. Preflight OPTIONS
                    if ($method -eq "OPTIONS") {
                        $header = "HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                        $hBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                        $stream.Write($hBytes, 0, $hBytes.Length)
                    }
                    # B. API /api/info
                    elseif ($path -eq "/api/info") {
                        $json = "{`"ip`":`"$LAN_IP`",`"port`":$PORT,`"status`":`"ok`"}"
                        $b = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $h = "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($b.Length)`r`nConnection: close`r`n`r`n"
                        $hBytes = [System.Text.Encoding]::ASCII.GetBytes($h)
                        $stream.Write($hBytes, 0, $hBytes.Length)
                        $stream.Write($b, 0, $b.Length)
                    }
                    # C. POST /api/scroll & /api/key
                    elseif ($method -eq "POST" -and ($path -eq "/api/scroll" -or $path -eq "/api/key")) {
                        $splitIndex = $rawRequest.IndexOf("`r`n`r`n")
                        $bodyStr = ""
                        if ($splitIndex -ge 0) {
                            $bodyStr = $rawRequest.Substring($splitIndex + 4)
                        }

                        $actionDone = ""
                        if ($bodyStr) {
                            try {
                                $data = $bodyStr | ConvertFrom-Json
                                if ($data.key) {
                                    $k = [string]$data.key.ToLower()
                                    if ($k -eq "next") {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_DOWN)
                                        $actionDone = "NEXT SLIDE / DOWN"
                                    } elseif ($k -eq "prev") {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_UP)
                                        $actionDone = "PREV SLIDE / UP"
                                    } elseif ($k -in @("playpause", "play", "pause")) {
                                        [Win32Remote]::PlayPause()
                                        $actionDone = "PLAY / PAUSE"
                                    } elseif ($k -in @("volup", "volume_up")) {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_VOLUME_UP)
                                        [Win32Remote]::PressKey([Win32Remote]::VK_VOLUME_UP)
                                        $actionDone = "VOLUME NAIK (+)"
                                    } elseif ($k -in @("voldown", "volume_down")) {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_VOLUME_DOWN)
                                        [Win32Remote]::PressKey([Win32Remote]::VK_VOLUME_DOWN)
                                        $actionDone = "VOLUME TURUN (-)"
                                    } elseif ($k -in @("mute", "volume_mute")) {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_VOLUME_MUTE)
                                        $actionDone = "MUTE AUDIO"
                                    }
                                }
                                if ($data.swipe) {
                                    $sw = [string]$data.swipe.ToLower()
                                    if ($sw -in @("next", "down")) {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_DOWN)
                                        [Win32Remote]::ScrollMouse(-120)
                                        $actionDone = "SWIPE NEXT (1 VIDEO)"
                                    } elseif ($sw -in @("prev", "up")) {
                                        [Win32Remote]::PressKey([Win32Remote]::VK_UP)
                                        [Win32Remote]::ScrollMouse(120)
                                        $actionDone = "SWIPE PREV (1 VIDEO)"
                                    }
                                }
                                if ($null -ne $data.velocity -and [math]::Abs([double]$data.velocity) -gt 0.15) {
                                    $vel = [double]$data.velocity
                                    $step = -$vel * 18.0
                                    $wheelAccumulator += $step
                                    $delta = [int]$wheelAccumulator
                                    if ([math]::Abs($delta) -ge 20) {
                                        [Win32Remote]::ScrollMouse($delta)
                                        $wheelAccumulator -= $delta
                                    }
                                }
                            } catch {}
                        }

                        if ($actionDone) {
                            $timeStr = (Get-Date).ToString("HH:mm:ss")
                            Write-Host "  [$timeStr] Perintah diterima: $actionDone" -ForegroundColor Green
                        }

                        $respJson = '{"status":"ok"}'
                        $b = [System.Text.Encoding]::UTF8.GetBytes($respJson)
                        $h = "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($b.Length)`r`nConnection: close`r`n`r`n"
                        $hBytes = [System.Text.Encoding]::ASCII.GetBytes($h)
                        $stream.Write($hBytes, 0, $hBytes.Length)
                        $stream.Write($b, 0, $b.Length)
                    }
                    # D. Unduh REMOTE_DARURAT.bat
                    elseif ($method -eq "GET" -and ($path -eq "/REMOTE_DARURAT.bat" -or $path -eq "/download" -or $path -eq "/download/REMOTE_DARURAT.bat")) {
                        $batFile = "d:\APP\My\REMOTE_DARURAT.bat"
                        if (-not (Test-Path $batFile)) {
                            $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
                            if ($scriptDir) { $batFile = Join-Path $scriptDir "REMOTE_DARURAT.bat" }
                        }
                        if (Test-Path $batFile) {
                            $batBytes = [System.IO.File]::ReadAllBytes($batFile)
                            $h = "HTTP/1.1 200 OK`r`nContent-Type: application/octet-stream`r`nContent-Disposition: attachment; filename=`"REMOTE_DARURAT.bat`"`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($batBytes.Length)`r`nConnection: close`r`n`r`n"
                            $hBytes = [System.Text.Encoding]::ASCII.GetBytes($h)
                            $stream.Write($hBytes, 0, $hBytes.Length)
                            $stream.Write($batBytes, 0, $batBytes.Length)
                        }
                    }
                    # E. GET / atau /remote.html
                    elseif ($method -eq "GET" -and ($path -eq "/" -or $path -eq "/remote.html" -or $path -eq "/index.html")) {
                        $h = "HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: $($remoteHtmlBytes.Length)`r`nConnection: close`r`n`r`n"
                        $hBytes = [System.Text.Encoding]::ASCII.GetBytes($h)
                        $stream.Write($hBytes, 0, $hBytes.Length)
                        $stream.Write($remoteHtmlBytes, 0, $remoteHtmlBytes.Length)
                    }
                    else {
                        $nf = "HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                        $hBytes = [System.Text.Encoding]::ASCII.GetBytes($nf)
                        $stream.Write($hBytes, 0, $hBytes.Length)
                    }

                    $stream.Flush()
                }
            } finally {
                try { $stream.Close() } catch {}
                try { $client.Close() } catch {}
            }
        } else {
            Start-Sleep -Milliseconds 15
        }
    } catch {
        Start-Sleep -Milliseconds 50
    }
}
