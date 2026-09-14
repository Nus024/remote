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

# 2. Otomatis Buka Windows Firewall Port 8000 jika memiliki hak akses
try {
    netsh advfirewall firewall add rule name="RemoteDarurat8000" dir=in action=allow protocol=TCP localport=$PORT profile=any >$null 2>&1
} catch {}

# 3. Compile Win32 Helper Cepat & Cerdas (Auto-Focus Window & Keyboard/Mouse)
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

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public const uint GW_HWNDNEXT = 2;
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
    public const uint MOUSEEVENTF_MOVE = 0x0001;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP = 0x0010;
    public const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    public const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
    public const uint MOUSEEVENTF_WHEEL = 0x0800;

    public static string GetActiveTitle() {
        IntPtr h = GetForegroundWindow();
        if (h == IntPtr.Zero) return "";
        StringBuilder sb = new StringBuilder(512);
        GetWindowText(h, sb, sb.Capacity);
        return sb.ToString();
    }

    // Pastikan jika jendela terminal yang aktif, fokus dipindahkan ke PowerPoint/Browser di belakangnya
    public static void EnsureTargetFocus() {
        IntPtr fg = GetForegroundWindow();
        if (fg == IntPtr.Zero) return;
        StringBuilder sb = new StringBuilder(512);
        GetWindowText(fg, sb, sb.Capacity);
        string t = sb.ToString().ToLower();

        if (t.Contains("cmd.exe") || t.Contains("powershell") || t.Contains("remote darurat") || t.Contains("terminal")) {
            IntPtr next = GetWindow(fg, GW_HWNDNEXT);
            while (next != IntPtr.Zero) {
                if (IsWindowVisible(next)) {
                    StringBuilder sbNext = new StringBuilder(512);
                    GetWindowText(next, sbNext, sbNext.Capacity);
                    string nt = sbNext.ToString().ToLower();
                    if (nt.Length > 0 && !nt.Contains("remote darurat") && !nt.Contains("cmd") && !nt.Contains("powershell") && !nt.Contains("terminal") && !nt.Equals("program manager")) {
                        SetForegroundWindow(next);
                        System.Threading.Thread.Sleep(20);
                        break;
                    }
                }
                next = GetWindow(next, GW_HWNDNEXT);
            }
        }
    }

    public static void PressKey(byte vk) {
        EnsureTargetFocus();
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        keybd_event(vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static void MoveMouse(int dx, int dy) {
        mouse_event(MOUSEEVENTF_MOVE, dx, dy, 0, UIntPtr.Zero);
    }

    public static void ClickLeft() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ClickRight() {
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ClickDouble() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(40);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void ScrollMouse(int delta) {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta, UIntPtr.Zero);
    }

    public static void PlayPause() {
        EnsureTargetFocus();
        string t = GetActiveTitle().ToLower();
        if (t.Contains("youtube")) {
            keybd_event(VK_K, 0, 0, UIntPtr.Zero);
            System.Threading.Thread.Sleep(15);
            keybd_event(VK_K, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        } else {
            keybd_event(VK_MEDIA_PLAY_PAUSE, 0, 0, UIntPtr.Zero);
            System.Threading.Thread.Sleep(15);
            keybd_event(VK_MEDIA_PLAY_PAUSE, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        }
    }
}
"@
Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue

# 4. Deteksi Seluruh Alamat IP Lokal Komputer Ini
$allIPs = @()
try {
    $netIPs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" }
    foreach ($item in $netIPs) {
        $allIPs += $item.IPAddress
    }
} catch {}

function Get-PrimaryIP {
    try {
        $s = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork, [System.Net.Sockets.SocketType]::Dgram, [System.Net.Sockets.ProtocolType]::Udp)
        $s.Connect("8.8.8.8", 80)
        $ip = $s.LocalEndPoint.Address.ToString()
        $s.Close()
        if ($ip -and $ip -ne "127.0.0.1") { return $ip }
    } catch {}

    if ($allIPs.Count -gt 0) { return $allIPs[0] }
    return "127.0.0.1"
}

$LAN_IP = Get-PrimaryIP

# 5. Embedded HTML (Decompress Gzip Base64)
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

# 6. Tampilkan Banner Status & Panduan Koneksi Lengkap
Clear-Host
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "             REMOTE PC DARURAT (1-FILE ZERO-INSTALL)                    " -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  ALAMAT IP LAPTOP INI :  $LAN_IP  (Port: $PORT)" -ForegroundColor Green
if ($allIPs.Count -gt 1) {
    Write-Host "  (IP Lain yang terdeteksi: $($allIPs -join ', '))" -ForegroundColor DarkGray
}
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  CARA MENGHUBUNGKAN DARI HP ANDA:" -ForegroundColor White
Write-Host "  1. Pastikan HP & laptop terhubung ke Wi-Fi / Hotspot yang sama." -ForegroundColor Gray
Write-Host "  2. Buka browser HP (Chrome / Safari) ketik alamat:" -ForegroundColor Gray
Write-Host "     http://${LAN_IP}:${PORT}" -ForegroundColor Yellow
Write-Host "     (ATAU buka remote yang ada di HP -> klik ikon [Gear] -> masukkan $LAN_IP)" -ForegroundColor DarkGray
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  JIKA DI HP MUNCUL 'TERPUTUS' ATAU TIDAK BISA KONEK:" -ForegroundColor Red
Write-Host "  - Windows Firewall: Ubah Wi-Fi di laptop ini dari 'Public' ke 'Private'." -ForegroundColor Gray
Write-Host "  - Atau klik kanan file ini -> pilih 'Run as administrator'." -ForegroundColor Gray
Write-Host "  - Atau gunakan Hotspot HP Anda (tethering) agar bebas isolasi router." -ForegroundColor Gray
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host "  STATUS: Siap menerima koneksi dari HP... (Tekan Ctrl+C untuk keluar)" -ForegroundColor Green
Write-Host ""

# 7. Inisialisasi TCP HTTP Listener
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $PORT)
try {
    $listener.Start()
} catch {
    Write-Host "Gagal membuka port $PORT. Error: $($_.Exception.Message)" -ForegroundColor Red
    pause
    exit 1
}

$wheelAccumulator = 0.0

# 8. Loop Penanganan Request HTTP dari HP (Crash-Proof & Auto-Recover)
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

                    # A. Preflight OPTIONS (CORS)
                    if ($method -eq "OPTIONS") {
                        $header = "HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
                        $hBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                        $stream.Write($hBytes, 0, $hBytes.Length)
                    }
                    # Favicon handler
                    elseif ($path -eq "/favicon.ico" -or $path -eq "/favicon.png") {
                        $header = "HTTP/1.1 204 No Content`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
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
                    # C. POST /api/scroll, /api/key, /api/mouse, /api/click
                    elseif ($method -eq "POST" -and ($path -eq "/api/scroll" -or $path -eq "/api/key" -or $path -eq "/api/mouse" -or $path -eq "/api/click")) {
                        $splitIndex = $rawRequest.IndexOf("`r`n`r`n")
                        $bodyStr = ""
                        if ($splitIndex -ge 0) {
                            $bodyStr = $rawRequest.Substring($splitIndex + 4)
                        }

                        $actionDone = ""
                        if ($bodyStr) {
                            try {
                                $data = $bodyStr | ConvertFrom-Json
                                # 1. Gerakan Kursor Mouse (Trackpad HP)
                                if ($null -ne $data.dx -or $null -ne $data.dy) {
                                    $mx = if ($null -ne $data.dx) { [int][Math]::Round([double]$data.dx) } else { 0 }
                                    $my = if ($null -ne $data.dy) { [int][Math]::Round([double]$data.dy) } else { 0 }
                                    if ($mx -ne 0 -or $my -ne 0) {
                                        [Win32Remote]::MoveMouse($mx, $my)
                                    }
                                }
                                # 2. Klik Mouse (Kiri, Kanan, Double Klik)
                                $clickBtn = if ($data.click) { [string]$data.click } elseif ($data.button) { [string]$data.button } elseif ($data.action) { [string]$data.action } else { "" }
                                if ($clickBtn) {
                                    $cb = $clickBtn.ToLower()
                                    if ($cb -in @("left", "kiri", "click_left", "left_click")) {
                                        [Win32Remote]::ClickLeft()
                                        $actionDone = "KLIK KIRI (MOUSE)"
                                    } elseif ($cb -in @("right", "kanan", "click_right", "right_click")) {
                                        [Win32Remote]::ClickRight()
                                        $actionDone = "KLIK KANAN (MOUSE)"
                                    } elseif ($cb -in @("double", "ganda", "double_click")) {
                                        [Win32Remote]::ClickDouble()
                                        $actionDone = "DOUBLE KLIK (MOUSE)"
                                    }
                                }
                                # 3. Scroll Roda Mouse (Scroll Strip / Tombol / Dua Jari)
                                if ($null -ne $data.scroll) {
                                    $sDelta = [int][Math]::Round([double]$data.scroll)
                                    if ($sDelta -ne 0) {
                                        [Win32Remote]::ScrollMouse($sDelta)
                                        $actionDone = "SCROLL MOUSE ($sDelta)"
                                    }
                                }
                                if ($null -ne $data.notch) {
                                    $dir = [int]$data.notch
                                    $deltaNotch = if ($dir -gt 0) { -120 } else { 120 }
                                    [Win32Remote]::ScrollMouse($deltaNotch)
                                    $actionDone = "SCROLL NOTCH ($deltaNotch)"
                                }
                                # 4. Tombol Shortcut & Media
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
                                # 5. Swipe 1 Video Shorts / TikTok
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
                                # 6. Continuous Velocity (Gulir Halus)
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
                    elseif ($method -eq "GET" -and ($path -eq "/" -or $path -eq "/remote" -or $path -eq "/remote.html")) {
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
