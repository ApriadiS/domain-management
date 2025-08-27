#!/bin/bash
# ... (kode di atas tetap sama) ...

# --- Skrip Utama ---

# 1. Cek hak akses root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Error: Skrip ini harus dijalankan sebagai root atau dengan sudo.${NC}"
  exit 1
fi

# PERBAIKAN: Tambahkan flag untuk mode penghapusan total
CLEAN_MODE=0
if [[ "$1" == "--clean" ]]; then
    CLEAN_MODE=1
fi

# PERBAIKAN: Hapus layar dan tampilkan pesan selamat datang
clear
print_title "Selamat Datang di Skrip Hapus Domain"

# Pemeriksaan Prasyarat
print_title "PRA-PEMERIKSAAN: Memastikan Aplikasi Terinstal"
if ! command -v nginx &> /dev/null; then echo -e "${RED}[!] Error: Nginx tidak terinstal.${NC}"; exit 1; else echo -e "${GREEN}[OK] Nginx terdeteksi.${NC}"; fi
if ! command -v certbot &> /dev/null; then echo -e "${RED}[!] Error: Certbot tidak terinstal.${NC}"; exit 1; else echo -e "${GREEN}[OK] Certbot terdeteksi.${NC}"; fi

# Jalankan Health Check
health_check

# ... (sisa skrip tetap sama sampai bagian penghapusan) ...

print_title "MEMULAI PROSES PEMBERSIHAN UNTUK: $SELECTED_DOMAIN"
NGINX_SYMLINK="/etc/nginx/sites-enabled/$SELECTED_DOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$SELECTED_DOMAIN"
run_silent "Menghapus sertifikat SSL" "certbot delete --cert-name '$SELECTED_DOMAIN' --non-interactive"
run_silent "Menonaktifkan situs" "rm -f '$NGINX_SYMLINK'"
run_silent "Menghapus konfigurasi Nginx" "rm -f '$NGINX_CONF'"

# PERBAIKAN: Tambahkan penghapusan file cadangan jika CLEAN_MODE aktif
if [ $CLEAN_MODE -eq 1 ]; then
    run_silent "Menghapus file konfigurasi cadangan" "rm -f /etc/nginx/sites-available/${SELECTED_DOMAIN}.bak"
    run_silent "Menghapus file konfigurasi cadangan .save" "rm -f /etc/nginx/sites-available/${SELECTED_DOMAIN}.save"
fi

run_silent "Menguji konfigurasi Nginx" "nginx -t"
run_silent "Me-reload Nginx" "systemctl reload nginx"

# PERBAIKAN: Pesan selesai yang konsisten
echo -e "\n${GREEN}===============================================================${NC}"
if [ $CLEAN_MODE -eq 1 ]; then
    echo -e "${GREEN} ✅ PENGHAPUSAN BERSIH SELESAI ✅ "
else
    echo -e "${GREEN} ✅ PENGHAPUSAN STANDAR SELESAI ✅ "
fi
echo -e "       Domain ${YELLOW}$SELECTED_DOMAIN${NC} telah dihapus sepenuhnya.       "
echo -e "${GREEN}===============================================================${NC}"