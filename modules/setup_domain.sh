#!/bin/bash

#================================================================================#
# Skrip Interaktif Nginx & Certbot (Versi 5.0 - Estetika & Clean UI)
# Menyembunyikan output sistem dan menggunakan spinner untuk proses yang berjalan.
# Memformat judul untuk kejelasan visual.
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

# Fungsi untuk menampilkan spinner saat proses berjalan
function spinner() {
    local pid=$1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\r"
    done
    printf "    \r"
}

# Fungsi untuk menjalankan perintah dengan senyap dan menampilkan spinner
function run_silent() {
    echo -n "[*] $1..."
    ("$2" >/dev/null 2>&1) &
    local pid=$!
    spinner $pid
    wait $pid
    if [ $? -eq 0 ]; then
        echo -e "[*] $1... ${GREEN}Selesai.${NC}"
    else
        echo -e "[*] $1... ${RED}Gagal.${NC}"
        # Tampilkan error jika ada (berguna untuk debugging)
        echo -e "${RED}[!] Perintah gagal. Harap periksa log atau jalankan manual.${NC}"
        exit 1
    fi
}
# ... (Fungsi validate_domain, is_port_in_use, get_location_config tetap sama persis) ...
function validate_domain(){ local d=$1;local r="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$";if [[ $d =~ $r ]];then return 0;else return 1;fi;}
function is_port_in_use(){ if ss -lntu|grep -q ":$1\b";then return 0;else return 1;fi;}
function get_location_config(){ local p=$1;local c="";while true;do read -p "$(echo -e ${YELLOW}"[?]"${NC}" Konfigurasi '${CYAN}${p}${NC}': [1] Port, [2] Direktori? ")" ch;case $ch in 1)while true;do read -p " -> Masukkan port: " port;if ! [[ $port =~ ^[0-9]+$ ]];then echo -e "${RED}[!] Port harus angka. Coba lagi.${NC}";continue;fi;if is_port_in_use $port;then echo -e "${RED}[!] Port ${port} sudah digunakan. Coba lagi.${NC}";continue;fi;c="
    location ${p} {
        proxy_pass http://localhost:${port};
        proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection \"Upgrade\";
    }";break;done;break;;2)while true;do read -p " -> Masukkan path direktori: " dir;if [ ! -d "$dir" ];then echo -e "${RED}[!] Direktori '${dir}' tidak ditemukan. Coba lagi.${NC}";continue;fi;if ! ls "$dir"/*.html 1>/dev/null 2>&1;then echo -e "${RED}[!] Tidak ada .html di '${dir}'. Coba lagi.${NC}";continue;fi;c="
    location ${p} {
        root ${dir}; index index.html index.htm; try_files \$uri \$uri/ =404;
    }";break;done;break;;*)echo -e "${RED}[!] Pilihan tidak valid.${NC}";;esac;done;echo "$c";}

# --- Skrip Utama ---

# 1. Cek hak akses root
if [ "$EUID" -ne 0 ]; then echo -e "${RED}[!] Harap jalankan skrip ini sebagai root atau dengan sudo.${NC}"; exit 1; fi
clear
print_title "Selamat Datang di Skrip Setup Domain Nginx & Certbot"

# 2. Minta dan validasi domain
while true; do
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" Masukkan nama domain utama: ")" DOMAIN
    if validate_domain "$DOMAIN"; then echo -e "${GREEN}[OK] Format domain '$DOMAIN' valid.${NC}"; break
    else echo -e "${RED}[!] Format domain tidak valid. Harap masukkan ulang.${NC}"; fi
done

# 3. Validasi DNS
print_title "PRA-KONFIGURASI: Validasi Arah DNS"
run_silent "Menginstal paket 'dnsutils' (jika perlu)" "apt-get update > /dev/null && apt-get install -y dnsutils"

VPS_IP=$(curl -s ifconfig.me)
echo "[*] IP Publik VPS ini adalah: ${YELLOW}${VPS_IP}${NC}"

while true; do
    echo -n "[*] Mengecek A record untuk '${DOMAIN}'..."
    DOMAIN_IP=$(dig +short "$DOMAIN" A | head -n 1)
    echo "" # Newline after check
    if [ -z "$DOMAIN_IP" ]; then
        echo -e "${RED}[!] Gagal: Domain '${DOMAIN}' tidak memiliki A record.${NC}"
    elif [ "$VPS_IP" == "$DOMAIN_IP" ]; then
        echo -e "${GREEN}[OK] Berhasil! Domain '${DOMAIN}' sudah mengarah ke IP VPS ini.${NC}"
        break
    else
        echo -e "${RED}[!] GAGAL: Domain '${DOMAIN}' mengarah ke ${DOMAIN_IP}, bukan ke ${VPS_IP}.${NC}"
    fi
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" [c]oba lagi validasi, atau [k]eluar? (c/k): ")" dns_choice
    if [[ "$dns_choice" =~ ^[Kk]$ ]]; then echo "[*] Skrip dihentikan."; exit 0; fi
done

# 4. Konfigurasi wajib untuk domain utama (root '/')
declare -a location_configs
print_title "LANGKAH 1: Konfigurasi Domain Utama ('/')"
root_config=$(get_location_config "/")
location_configs+=("$root_config")
echo -e "${GREEN}[OK] Konfigurasi untuk lokasi root '/' disimpan.${NC}"

# 5. Loop untuk penambahan route selanjutnya
print_title "LANGKAH 2: Konfigurasi Rute Tambahan (Opsional)"
while true; do
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" Apakah Anda ingin menambahkan rute lain? (y/n): ")" add_route
    if [[ "$add_route" =~ ^[Nn]$ ]]; then echo "[*] Tidak ada rute tambahan. Melanjutkan..."; break
    elif [[ "$add_route" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "    -> Masukkan path rute (diawali '/', contoh: /api): " route_path
            if [[ "$route_path" =~ ^/ ]]; then break
            else echo -e "${RED}[!] Path harus diawali '/'. Coba lagi.${NC}"; fi
        done
        sub_config=$(get_location_config "$route_path")
        location_configs+=("$sub_config")
        echo -e "${GREEN}[OK] Konfigurasi untuk rute '$route_path' disimpan.${NC}"
    else echo -e "${RED}[!] Jawaban tidak valid. Masukkan 'y' atau 'n'.${NC}"; fi
done

# 6. Setup Nginx dan Certbot
print_title "FINAL: Memulai Setup Nginx dan SSL"
all_locations=""
for config in "${location_configs[@]}"; do all_locations+="$config"; done
run_silent "Menginstal Nginx (jika perlu)" "apt-get install -y nginx"
run_silent "Menginstal Certbot (jika perlu)" "apt-get install -y certbot python3-certbot-nginx"

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
cat > $NGINX_CONF <<EOF
server { listen 80; server_name $DOMAIN; location /.well-known/acme-challenge/ { root /var/www/html; } location / { return 301 https://\$host\$request_uri; }}
EOF
run_silent "Mengaktifkan situs Nginx" "ln -s -f $NGINX_CONF /etc/nginx/sites-enabled/"
run_silent "Menguji konfigurasi Nginx" "nginx -t"
run_silent "Me-reload Nginx" "systemctl reload nginx"

read -p "$(echo -e ${YELLOW}"[?]"${NC}" Masukkan email Anda untuk notifikasi SSL: ")" user_email
run_silent "Menjalankan Certbot untuk mendapatkan sertifikat" "certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m '$user_email' --redirect"

echo -n "[*] Memperbarui konfigurasi Nginx dengan setup final..."
cat > $NGINX_CONF <<EOF
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    ${all_locations}
}
server {
    listen 80; server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
EOF
echo -e "${GREEN} Selesai.${NC}"
run_silent "Me-reload Nginx untuk terakhir kali" "systemctl reload nginx"

# Pesan Selesai
echo -e "\n${GREEN}===============================================================${NC}"
echo -e "${GREEN}                        ✅ SETUP SELESAI ✅                      ${NC}"
echo -e "         Domain ${YELLOW}https://$DOMAIN${NC} sekarang aktif.         "
echo -e "${GREEN}===============================================================${NC}"