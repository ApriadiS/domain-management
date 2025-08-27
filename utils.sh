#!/bin/bash
#================================================================================#
# Skrip Utilitas: utils.sh
# - Kumpulan fungsi bantu yang bisa digunakan kembali oleh skrip lain.
#================================================================================#

# --- Konfigurasi Visual & Fungsi Bantuan ---
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

# Fungsi untuk menjalankan perintah dengan senyap dan menampilkan spinner
function run_silent() {
    echo -n "[*] $1..."
    ("$2" >/dev/null 2>&1) &
    local pid=$!
    # Spinner
    local spinstr='|/-\'
    while ps -p $pid >/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "    \r"

    wait $pid
    if [ $? -eq 0 ]; then
        echo -e "[*] $1... ${GREEN}Selesai.${NC}"
    else
        echo -e "[*] $1... ${RED}Gagal.${NC}"
        # Tampilkan error jika ada
        echo -e "${RED}[!] Perintah gagal. Harap periksa log atau jalankan manual.${NC}"
        # Tidak exit, agar skrip pemanggil bisa menangani kegagalan
    fi
}
# Fungsi validasi domain
function validate_domain() { local d=$1; local r="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"; if [[ $d =~ $r ]]; then return 0; else return 1; fi; }
# Fungsi cek port
function is_port_in_use() { if ss -lntu | grep -q ":$1\b"; then return 0; else return 1; fi; }
# Fungsi untuk mendapatkan konfigurasi lokasi
function get_location_config() {
    local p=$1
    local c=""
    while true; do
        read -p "$(echo -e ${YELLOW}"[?]"${NC}" Konfigurasi '${CYAN}${p}${NC}': [1] Port, [2] Direktori? ")" ch
        case $ch in
            1)
                while true; do
                    read -p " -> Masukkan port: " port
                    if ! [[ $port =~ ^[0-9]+$ ]]; then echo -e "${RED}[!] Port harus angka. Coba lagi.${NC}"; continue; fi
                    if is_port_in_use $port; then echo -e "${RED}[!] Port ${port} sudah digunakan. Coba lagi.${NC}"; continue; fi
                    c="
    location ${p} {
        proxy_pass http://localhost:${port};
        proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \"Upgrade\";
    }"
                    break
                done
                break
                ;;
            2)
                while true; do
                    read -p " -> Masukkan path direktori: " dir
                    if [ ! -d "$dir" ]; then echo -e "${RED}[!] Direktori '${dir}' tidak ditemukan. Coba lagi.${NC}"; continue; fi
                    if ! ls "$dir"/*.html 1>/dev/null 2>&1; then echo -e "${RED}[!] Tidak ada .html di '${dir}'. Coba lagi.${NC}"; continue; fi
                    c="
    location ${p} {
        root ${dir}; index index.html index.htm; try_files \$uri \$uri/ =404;
    }"
                    break
                done
                break
                ;;
            *)
                echo -e "${RED}[!] Pilihan tidak valid.${NC}"
                ;;
        esac
    done
    echo "$c"
}