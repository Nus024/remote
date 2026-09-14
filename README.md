# Wireless PC Remote Controller

Aplikasi pengendali nirkabel dari layar HP (Smartphone) ke Layar PC/Laptop melalui jaringan Wi-Fi lokal.

## ✨ Fitur Utama
- **Kontrol Presentasi & Dokumen**: Navigasi slide PowerPoint, Google Slides, Canva, PDF, dan Word.
- **Kontrol Video & Media**: Dukungan penuh untuk YouTube, YouTube Shorts (1 usap = 1 video), TikTok Web, Reels, VLC, dan Media Player.
- **Kontrol Volume Master**: Tombol tactile `Vol -`, `Mute`, dan `Vol +` langsung ke sistem audio Windows.
- **Mode Darurat 1-File (Zero-Install)**: Cukup salin 1 file `REMOTE_DARURAT.bat` ke laptop panitia, jalan langsung tanpa install Python!
- **Dukungan Sentuh & Sensor Kamera**: Mendukung touchpad minimalis di HP atau gestur tangan/lirikan mata via kamera depan HP.

## 📁 Struktur File
1. **`REMOTE_DARURAT.bat`**: Server mandiri 1-file native Windows 10/11 (PowerShell & .NET) untuk laptop panitia / rapat darurat tanpa instalasi apa pun.
2. **`remote.html`**: Antarmuka web remote di HP (tersimpan di HP / diakses via browser HP).
3. **`server.py`**: Server bridge berbasis Python untuk laptop pribadi.
4. **`buka_wireless_pc.bat`**: Peluncur otomatis untuk server Python dan pembaca dokumen PC.
5. **`index.html`**: Web reader dokumen lokal di layar PC.

## 🚀 Cara Penggunaan Singkat

### Skenario A: Rapat Darurat (Laptop Panitia)
1. Salin `REMOTE_DARURAT.bat` ke laptop panitia dan klik 2x.
2. Di HP, buka remote -> klik ikon Gear (`⚙️`) -> masukkan IP laptop yang tertera.
3. Selesai! Presentasi dan volume laptop panitia langsung bisa dikendalikan dari HP.

### Skenario B: Laptop Pribadi
1. Jalankan `buka_wireless_pc.bat`.
2. Buka `http://<IP_LAPTOP>:8000/remote.html` di browser HP Anda.

## 🌐 Deploy ke Vercel (Opsional)
Aplikasi ini sudah dilengkapi file konfigurasi `vercel.json`:
1. Push repositori ini ke GitHub.
2. Buka [Vercel](https://vercel.com) dan impor repositori GitHub Anda.
3. Klik **Deploy**.
   - URL utama (`/`) akan langsung membuka antarmuka `remote.html`.
   - URL `/download` akan langsung mengunduh `REMOTE_DARURAT.bat`.

