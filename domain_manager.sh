#!/bin/bash

#================================================================================#
# Skrip Utama: Domain Manager Interaktif (Versi 2.0 - Tambahan Opsi Hapus Bersih)
# - Sebuah menu sederhana untuk mengelola skrip setup dan penghapusan domain.
# - Menambahkan opsi untuk menghapus semua file terkait (config, sertifikat, dan backup).
#================================================================================#

# --- Konfigurasi Visual ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fungsi untuk menampilkan judul berformat
function print_title() {
    echo -e "\n${CYAN}===============================================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}===============================================================${NC}"
}

# --- Skrip Utama ---

# 1. Cek hak akses root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Harap jalankan skrip ini sebagai root atau dengan sudo.${NC}"
  exit 1
fi

# 2. Tampilkan Menu Utama
clear
print_title "Panel Kontrol Manajemen Domain"
echo -e "Silakan pilih tindakan yang ingin Anda lakukan:"
echo ""
echo -e "  ${YELLOW}1.${NC}  Setup Domain Baru"
echo -e "  ${YELLOW}2.${NC}  Hapus Domain yang Ada (Standar)"
echo -e "  ${YELLOW}3.${NC}  Hapus Bersih Domain & Semua File Terkait"
echo -e "  ${YELLOW}0.${NC}  Keluar"
echo ""

# 3. Minta input pengguna dan validasi
while true; do
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" Masukkan nomor pilihan Anda: ")" CHOICE
    if ! [[ "$CHOICE" =~ ^[0-3]$ ]]; then
        echo -e "${RED}[!] Pilihan tidak valid. Silakan coba lagi.${NC}"
        continue
    fi
    break
done

# 4. Jalankan skrip yang dipilih
case "$CHOICE" in
    1)
        print_title "Memulai Setup Domain Baru..."
        if [ ! -f "modules/setup_domain.sh" ]; then
            echo -e "${RED}[!] Error: File 'modules/setup_domain.sh' tidak ditemukan.${NC}"
            exit 1
        fi
        chmod +x modules/setup_domain.sh
        bash modules/setup_domain.sh
        ;;
    2)
        print_title "Memulai Proses Penghapusan Domain (Standar)..."
        if [ ! -f "modules/remove_domain.sh" ]; then
            echo -e "${RED}[!] Error: File 'modules/remove_domain.sh' tidak ditemukan.${NC}"
            exit 1
        fi
        chmod +x modules/remove_domain.sh
        bash modules/remove_domain.sh
        ;;
    3)
        print_title "Memulai Penghapusan Bersih Domain..."
        if [ ! -f "modules/remove_domain.sh" ]; then
            echo -e "${RED}[!] Error: File 'modules/remove_domain.sh' tidak ditemukan.${NC}"
            exit 1
        fi
        chmod +x modules/remove_domain.sh
        # Menjalankan skrip penghapusan dengan flag khusus
        bash modules/remove_domain.sh --clean
        ;;
    0)
        echo "[*] Proses dibatalkan. Selamat tinggal!"
        exit 0
        ;;
esac

exit 0