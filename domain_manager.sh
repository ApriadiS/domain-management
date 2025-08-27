#!/bin/bash

#================================================================================#
# Skrip Utama: Domain Manager Interaktif (Versi 2.2 - Modular)
# - Mengelola skrip setup dan penghapusan domain.
# - Menggunakan file `utils.sh` untuk fungsi bantu.
# - Menjalankan skrip dari folder `modules`.
#================================================================================#

# Impor file berisi fungsi-fungsi bantu
# Penting: Pastikan `utils.sh` berada di direktori yang sama dengan skrip ini.
source "utils.sh"

# Cek hak akses root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Harap jalankan skrip ini sebagai root atau dengan sudo.${NC}"
  exit 1
fi

# Pra-pemeriksaan di skrip utama
print_title "PRA-PEMERIKSAAN: Memastikan Aplikasi Terinstal"
if ! command -v nginx &> /dev/null; then echo -e "${RED}[!] Error: Nginx tidak terinstal.${NC}"; exit 1; else echo -e "${GREEN}[OK] Nginx terdeteksi.${NC}"; fi
if ! command -v certbot &> /dev/null; then echo -e "${RED}[!] Error: Certbot tidak terinstal.${NC}"; exit 1; else echo -e "${GREEN}[OK] Certbot terdeteksi.${NC}"; fi

# Cek keberadaan file modul
if [ ! -f "modules/setup_domain.sh" ] || [ ! -f "modules/remove_domain.sh" ]; then
    echo -e "${RED}[!] Error: File modul tidak ditemukan. Pastikan folder 'modules' berisi 'setup_domain.sh' dan 'remove_domain.sh'.${NC}"
    exit 1
fi

# Impor skrip modul
source modules/setup_domain.sh
source modules/remove_domain.sh

# Tampilkan Menu Utama
clear
print_title "Panel Kontrol Manajemen Domain"
echo -e "Silakan pilih tindakan yang ingin Anda lakukan:"
echo ""
echo -e "  ${YELLOW}1.${NC}  Setup Domain Baru"
echo -e "  ${YELLOW}2.${NC}  Hapus Domain yang Ada (Standar)"
echo -e "  ${YELLOW}3.${NC}  Hapus Bersih Domain & Semua File Terkait"
echo -e "  ${YELLOW}0.${NC}  Keluar"
echo ""

# Minta input pengguna dan validasi
while true; do
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" Masukkan nomor pilihan Anda: ")" CHOICE
    if ! [[ "$CHOICE" =~ ^[0-3]$ ]]; then
        echo -e "${RED}[!] Pilihan tidak valid. Silakan coba lagi.${NC}"
        continue
    fi
    break
done

# Panggil fungsi utama dari modul
case "$CHOICE" in
    1)
        main_setup
        ;;
    2)
        main_remove
        ;;
    3)
        main_remove "--clean"
        ;;
    0)
        echo "[*] Proses dibatalkan. Selamat tinggal!"
        exit 0
        ;;
esac

exit 0