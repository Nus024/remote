"""
Server Sinkronisasi Nirkabel (Wireless Gesture Bridge)
Menghubungkan HP (Kamera / Gestur Sentuh) ke Layar PC/Laptop melalui Wi-Fi Lokal.
Mendukung:
1. Pengendalian Halaman Web Reader di Layar PC (via SSE / Server-Sent Events)
2. Pengendalian Seluruh Web & Aplikasi Windows:
   - YouTube Shorts, TikTok, Reels (1 Swipe = 1 Video via VK_DOWN/VK_UP & Wheel)
   - YouTube Biasa, Situs Web, PDF, Word (Gulir Halus Kontinu via Native Mouse Wheel)
"""

import sys
import os

# Kompatibilitas pythonw.exe (tanpa jendela konsol, sys.stdout / sys.stderr adalah None)
try:
    log_file = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'error.log'), 'a', encoding='utf-8')
    if sys.stdout is None:
        sys.stdout = log_file
    if sys.stderr is None:
        sys.stderr = log_file
except Exception:
    pass
import json
import socket
import threading
import queue
import time
import ctypes
from ctypes import wintypes
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
KEYEVENTF_KEYUP = 0x0002
VK_DOWN = 0x28
VK_UP = 0x26
VK_SPACE = 0x20
VK_NEXT = 0x22
VK_PRIOR = 0x21
VK_VOLUME_MUTE = 0xAD
VK_VOLUME_DOWN = 0xAE
VK_VOLUME_UP = 0xAF

DESKTOP_ALL_ACCESS = 0x01FF

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

# Pastikan signature Win32 API 64-bit aman
user32.GetForegroundWindow.restype = wintypes.HWND
user32.SetForegroundWindow.argtypes = [wintypes.HWND]
user32.SetForegroundWindow.restype = wintypes.BOOL
user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
user32.SetCursorPos.argtypes = [ctypes.c_int, ctypes.c_int]
user32.GetCursorPos.argtypes = [ctypes.POINTER(wintypes.POINT)]
user32.mouse_event.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, wintypes.DWORD, ctypes.c_ulong]
user32.keybd_event.argtypes = [wintypes.BYTE, wintypes.BYTE, wintypes.DWORD, ctypes.c_ulong]

wheel_accumulator = 0.0
mouse_x_accum = 0.0
mouse_y_accum = 0.0

def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

LAN_IP = get_lan_ip()
PORT = 8000

def attach_thread_desktop():
    """Memastikan thread penangan HTTP terhubung ke Desktop interaktif Windows (Default)"""
    try:
        hdesk = user32.OpenDesktopW("Default", 0, False, DESKTOP_ALL_ACCESS)
        if hdesk:
            user32.SetThreadDesktop(hdesk)
    except Exception:
        pass

def get_active_or_browser_window():
    """Cari jendela aktif atau browser YouTube/TikTok/Reader di layar Windows"""
    attach_thread_desktop()
    fg = user32.GetForegroundWindow()
    if fg:
        title_buf = ctypes.create_unicode_buffer(512)
        user32.GetWindowTextW(fg, title_buf, 512)
        t = title_buf.value.lower()
        # Jika jendela depan sudah browser / YouTube / TikTok / Media, pakai langsung
        if any(b in t for b in ['brave', 'chrome', 'edge', 'firefox', 'opera', 'youtube', 'tiktok']):
            return fg
        # Jika jendela depan bukan IDE/terminal/explorer, tetap hormati jendela pilihan pengguna
        if not any(b in t for b in ['antigravity', 'code', 'cmd', 'powershell', 'terminal']):
            return fg

    # Jika sedang fokus di IDE/terminal, cari jendela browser teratas
    target = [None]
    def enum_cb(hwnd, lparam):
        if user32.IsWindowVisible(hwnd) and not user32.IsIconic(hwnd):
            buff = ctypes.create_unicode_buffer(512)
            user32.GetWindowTextW(hwnd, buff, 512)
            bt = buff.value.lower()
            if any(b in bt for b in ['brave', 'chrome', 'edge', 'firefox', 'opera', 'youtube', 'tiktok']):
                target[0] = hwnd
                return False
        return True

    WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    hdesk = user32.OpenDesktopW("Default", 0, False, DESKTOP_ALL_ACCESS)
    if hdesk:
        user32.EnumDesktopWindows(hdesk, WNDENUMPROC(enum_cb), 0)
    return target[0] or fg

def ensure_window_active_and_cursor_ready(hwnd=None):
    """Fokuskan jendela target dan pastikan kursor mouse berada di tengah viewport halaman"""
    attach_thread_desktop()
    if not hwnd:
        hwnd = get_active_or_browser_window()
    if not hwnd or not user32.IsWindow(hwnd):
        return

    fg = user32.GetForegroundWindow()
    if fg != hwnd:
        try:
            if user32.IsIconic(hwnd):
                user32.ShowWindow(hwnd, 9)  # SW_RESTORE
            else:
                user32.ShowWindow(hwnd, 5)  # SW_SHOW
            fg_thread = user32.GetWindowThreadProcessId(fg, None)
            curr_thread = kernel32.GetCurrentThreadId()
            user32.AttachThreadInput(curr_thread, fg_thread, True)
            user32.SetForegroundWindow(hwnd)
            user32.SetFocus(hwnd)
            user32.AttachThreadInput(curr_thread, fg_thread, False)
        except Exception:
            pass

    # Periksa posisi kursor mouse
    # Di Windows 10/11, mouse wheel dikirim ke jendela/area di bawah koordinat kursor.
    # Jika kursor di luar konten (misal di titlebar, tab, atau (0,0)), letakkan di tengah konten.
    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    pt = wintypes.POINT()
    user32.GetCursorPos(ctypes.byref(pt))

    if (pt.x < rect.left + 50 or pt.x > rect.right - 50 or
        pt.y < rect.top + 140 or pt.y > rect.bottom - 50):
        mid_x = (rect.left + rect.right) // 2
        mid_y = max(rect.top + 260, (rect.top + rect.bottom) // 2)
        user32.SetCursorPos(mid_x, mid_y)

def move_mouse(dx, dy):
    """Gerakkan kursor mouse Windows secara relatif dengan akumulator presisi tinggi"""
    global mouse_x_accum, mouse_y_accum
    attach_thread_desktop()
    try:
        mouse_x_accum += float(dx)
        mouse_y_accum += float(dy)
        step_x = int(mouse_x_accum)
        step_y = int(mouse_y_accum)
        if step_x != 0 or step_y != 0:
            user32.mouse_event(MOUSEEVENTF_MOVE, step_x, step_y, 0, 0)
            mouse_x_accum -= step_x
            mouse_y_accum -= step_y
    except Exception as e:
        print("Gagal gerakkan mouse Windows:", e)

def mouse_click(button='left'):
    """Simulasi klik kiri, klik kanan, atau klik ganda mouse Windows"""
    attach_thread_desktop()
    btn = str(button).lower()
    try:
        if btn in ('left', 'kiri'):
            user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
            time.sleep(0.015)
            user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        elif btn in ('right', 'kanan'):
            user32.mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
            time.sleep(0.015)
            user32.mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
        elif btn in ('double', 'double_click', 'ganda'):
            user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
            time.sleep(0.015)
            user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
            time.sleep(0.04)
            user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
            time.sleep(0.015)
            user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        elif btn in ('middle', 'tengah'):
            user32.mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0)
            time.sleep(0.015)
            user32.mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0)
        return True
    except Exception as e:
        print("Gagal klik mouse Windows:", e)
        return False

def scroll_windows(velocity):
    """Simulasi roda mouse Windows (Mouse Wheel) untuk menggulir YouTube, TikTok, Reader, PDF, dll."""
    global wheel_accumulator
    attach_thread_desktop()
    ensure_window_active_and_cursor_ready()
    try:
        # Nilai negatif velocity = scroll ke atas (wheel_delta positif)
        # Nilai positif velocity = scroll ke bawah (wheel_delta negatif)
        step = -velocity * 18.0
        wheel_accumulator += step
        delta_to_send = int(wheel_accumulator)
        if abs(delta_to_send) >= 20:
            user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta_to_send, 0)
            wheel_accumulator -= delta_to_send
    except Exception as e:
        print("Gagal simulasi mouse wheel Windows:", e)

def scroll_notch(direction, notches=1):
    """Kirim tepat 1 atau lebih notch roda mouse standar Windows (120 per notch)"""
    attach_thread_desktop()
    ensure_window_active_and_cursor_ready()
    try:
        delta = -120 * notches if direction > 0 else 120 * notches
        user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta, 0)
    except Exception as e:
        print("Gagal simulasi mouse wheel notch:", e)

def handle_play_pause(hwnd=None):
    """Simulasi Play / Pause cerdas dan handal untuk YouTube, TikTok, dan Media Lainnya"""
    attach_thread_desktop()
    if not hwnd:
        hwnd = get_active_or_browser_window()
    if not hwnd or not user32.IsWindow(hwnd):
        return False

    ensure_window_active_and_cursor_ready(hwnd)

    title_buf = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(hwnd, title_buf, 512)
    title = title_buf.value.lower()

    # 1. KASUS YOUTUBE (Shorts maupun Video Biasa)
    if 'youtube' in title:
        # Tombol 'k' adalah shortcut resmi universal player YouTube untuk Play / Pause
        # 'k' tidak akan pernah salah fungsi atau men-scroll halaman seperti Spasi
        user32.keybd_event(0x4B, 0, 0, 0)  # VK_K
        time.sleep(0.02)
        user32.keybd_event(0x4B, 0, KEYEVENTF_KEYUP, 0)
        return True

    # 2. KASUS TIKTOK (Desktop Web)
    elif 'tiktok' in title:
        # Di TikTok web, klik langsung di area pemutar video di tengah layar adalah cara paling pasti untuk Play / Pause
        rect = wintypes.RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(rect))
        mid_x = (rect.left + rect.right) // 2
        mid_y = max(rect.top + 260, (rect.top + rect.bottom) // 2)
        user32.SetCursorPos(mid_x, mid_y)
        time.sleep(0.02)
        MOUSEEVENTF_LEFTDOWN = 0x0002
        MOUSEEVENTF_LEFTUP = 0x0004
        user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
        time.sleep(0.02)
        user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        return True

    # 3. PLATFORM LAIN (Instagram Reels, Spotify, Netflix, VLC, Media Player Windows, dll.)
    else:
        # Gunakan Hardware Media Key Windows (VK_MEDIA_PLAY_PAUSE = 0xB3)
        VK_MEDIA_PLAY_PAUSE = 0xB3
        user32.keybd_event(VK_MEDIA_PLAY_PAUSE, 0, 0, 0)
        time.sleep(0.02)
        user32.keybd_event(VK_MEDIA_PLAY_PAUSE, 0, KEYEVENTF_KEYUP, 0)
        # JANGAN gunakan VK_SPACE karena Spasi pada browser selalu memicu scroll ke bawah (Next)!
        # Klik pada tengah area video
        rect = wintypes.RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(rect))
        mid_x = (rect.left + rect.right) // 2
        mid_y = max(rect.top + 260, (rect.top + rect.bottom) // 2)
        user32.SetCursorPos(mid_x, mid_y)
        time.sleep(0.02)
        MOUSEEVENTF_LEFTDOWN = 0x0002
        MOUSEEVENTF_LEFTUP = 0x0004
        user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
        time.sleep(0.02)
        user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
        return True

def press_key(key_name):
    """Simulasi tombol keyboard / kontrol Play-Pause cerdas untuk YouTube, TikTok, dll."""
    attach_thread_desktop()
    hwnd = get_active_or_browser_window()
    ensure_window_active_and_cursor_ready(hwnd)

    k = str(key_name).lower()
    if k in ('playpause', 'play', 'pause'):
        return handle_play_pause(hwnd)

    if k in ('volume_up', 'volup', 'vol_up'):
        for _ in range(2):
            user32.keybd_event(VK_VOLUME_UP, 0, 0, 0)
            time.sleep(0.01)
            user32.keybd_event(VK_VOLUME_UP, 0, KEYEVENTF_KEYUP, 0)
            time.sleep(0.01)
        return True
    elif k in ('volume_down', 'voldown', 'vol_down'):
        for _ in range(2):
            user32.keybd_event(VK_VOLUME_DOWN, 0, 0, 0)
            time.sleep(0.01)
            user32.keybd_event(VK_VOLUME_DOWN, 0, KEYEVENTF_KEYUP, 0)
            time.sleep(0.01)
        return True
    elif k in ('volume_mute', 'mute', 'vol_mute'):
        user32.keybd_event(VK_VOLUME_MUTE, 0, 0, 0)
        time.sleep(0.01)
        user32.keybd_event(VK_VOLUME_MUTE, 0, KEYEVENTF_KEYUP, 0)
        return True

    key_map = {
        'next': VK_DOWN,
        'prev': VK_UP,
        'pagedown': VK_NEXT,
        'pageup': VK_PRIOR,
        'space': VK_SPACE,
        'k': 0x4B
    }
    vk = key_map.get(k)
    if vk:
        try:
            user32.keybd_event(vk, 0, 0, 0)
            time.sleep(0.015)
            user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)
            return True
        except Exception as e:
            print("Gagal simulasi keyboard Windows:", e)
    return False

def handle_swipe(action):
    """Navigasi video YouTube Shorts, TikTok, atau Reels dengan proteksi ganda (Key + Wheel)"""
    attach_thread_desktop()
    ensure_window_active_and_cursor_ready()
    act = str(action).lower()
    if act in ('next', 'down'):
        press_key('next')
        user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, -120, 0)
    elif act in ('prev', 'up'):
        press_key('prev')
        user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, 120, 0)

class WirelessBridgeHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Tambahkan header CORS agar HP dan PC dapat berkomunikasi bebas
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        # 0. Favicon handler (cegah error 404 di konsol peramban)
        if clean_path in ('/favicon.ico', '/favicon.png'):
            self.send_response(204)
            self.end_headers()
            return

        # 1. Download REMOTE_DARURAT.bat
        if clean_path in ('/REMOTE_DARURAT.bat', '/download', '/download/REMOTE_DARURAT.bat'):
            file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'REMOTE_DARURAT.bat')
            if os.path.exists(file_path):
                with open(file_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', 'attachment; filename="REMOTE_DARURAT.bat"')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        # 2. Clean URL Routes (Sesuai vercel.json)
        # HP / Root / /remote -> otomatis sajikan remote.html
        if clean_path in ('', '/', '/remote', '/remote.html'):
            file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'remote.html')
            if os.path.exists(file_path):
                with open(file_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

        # 3. API Informasi Server & IP
        if clean_path == '/api/info':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            info = {
                'ip': LAN_IP,
                'port': PORT,
                'remoteUrl': f'http://{LAN_IP}:{PORT}/remote'
            }
            self.wfile.write(json.dumps(info).encode('utf-8'))
            return

        # 4. File statis lainnya
        super().do_GET()

    def do_POST(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path in ('/api/scroll', '/api/key', '/api/mouse', '/api/click'):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')
            try:
                data = json.loads(body)

                # 1. Gerakan kursor mouse (Trackpad / Touchpad)
                if 'dx' in data or 'dy' in data:
                    move_mouse(data.get('dx', 0), data.get('dy', 0))

                # 2. Klik mouse (Kiri, Kanan, Double click)
                if 'click' in data or 'button' in data:
                    btn = data.get('click') or data.get('button')
                    mouse_click(btn)

                if 'action' in data:
                    act = str(data['action']).lower()
                    if act in ('left', 'click_left', 'left_click', 'kiri'):
                        mouse_click('left')
                    elif act in ('right', 'click_right', 'right_click', 'kanan'):
                        mouse_click('right')
                    elif act in ('double', 'double_click', 'ganda'):
                        mouse_click('double')

                # 3. Tombol keyboard khusus (Play/Pause, Volume, dll.)
                if 'key' in data:
                    press_key(data['key'])

                # 4. Swipe video Shorts/TikTok (Pasti 1 video per swipe)
                if 'swipe' in data:
                    handle_swipe(data['swipe'])

                # 5. Notch roda mouse wheel (Scroll diskrit)
                if 'notch' in data:
                    direction = int(data['notch'])
                    scroll_notch(direction)

                # 6. Aliran scroll roda mouse kontinu (Mouse Wheel)
                if 'scroll' in data:
                    scroll_windows(float(data['scroll']))
                elif 'velocity' in data:
                    velocity = float(data.get('velocity', 0))
                    if abs(velocity) > 0.15:
                        scroll_windows(velocity)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"status": "ok"}')
            except Exception as e:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(str(e).encode('utf-8'))
            return

        self.send_response(404)
        self.end_headers()

class DualStackServer(ThreadingHTTPServer):
    def server_bind(self):
        try:
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        except (AttributeError, OSError):
            pass
        return super().server_bind()

def kill_competing_servers():
    """Tutup proses python lain yang mungkin masih menggantung di port 8000"""
    curr_pid = os.getpid()
    try:
        import subprocess
        out = subprocess.check_output(f'netstat -ano | findstr ":{PORT}"', shell=True).decode()
        pids_to_kill = set()
        for line in out.strip().splitlines():
            parts = line.split()
            if len(parts) >= 5 and 'LISTENING' in parts:
                pid = int(parts[-1])
                if pid != curr_pid and pid > 0:
                    pids_to_kill.add(pid)
        for pid in pids_to_kill:
            try:
                subprocess.run(f'taskkill /F /PID {pid}', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                time.sleep(0.3)
            except Exception:
                pass
    except Exception:
        pass

def run_server():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    kill_competing_servers()

    DualStackServer.address_family = socket.AF_INET
    server = DualStackServer(('0.0.0.0', PORT), WirelessBridgeHandler)

    print("=" * 60)
    print("      SERVER UNIVERSAL PC REMOTE CONTROLLER AKTIF")
    print("=" * 60)
    print(f"Remote HP (Wi-Fi)   : http://{LAN_IP}:{PORT}")
    print(f"Akses Lokal PC      : http://localhost:{PORT}")
    print("=" * 60)
    print("Siap mengontrol: YouTube Shorts, TikTok, Video, Audio & Windows.")
    print("Tekan Ctrl+C di terminal ini untuk berhenti.\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer dihentikan.")

if __name__ == '__main__':
    try:
        run_server()
    except Exception:
        import traceback
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'error.log'), 'a', encoding='utf-8') as f:
            f.write(traceback.format_exc() + '\n')
