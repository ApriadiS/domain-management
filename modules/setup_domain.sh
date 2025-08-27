#!/bin/bash

#================================================================================#
# Skrip Interaktif Nginx & Certbot
# - Dijalankan sebagai modul dari domain_manager.sh
# - Semua fungsi bantu diimpor dari skrip utama.
#================================================================================#

function main_setup() {
    clear
    print_title "Selamat Datang di Skrip Setup Domain Nginx & Certbot"

    # 1. Minta dan validasi domain
    while true; do
        read -p "$(echo -e ${YELLOW}"[?]"${NC}" Masukkan nama domain utama: ")" DOMAIN
        if validate_domain "$DOMAIN"; then
            echo -e "${GREEN}[OK] Format domain '$DOMAIN' valid.${NC}"
            break
        else
            echo -e "${RED}[!] Format domain tidak valid. Harap masukkan ulang.${NC}"
        fi
    done

    # 2. Validasi DNS
    print_title "PRA-KONFIGURASI: Validasi Arah DNS"
    run_silent "Menginstal paket 'dnsutils' (jika perlu)" "apt-get update && apt-get install -y dnsutils"

    VPS_IP=$(curl -s ifconfig.me)
    echo "[*] IP Publik VPS ini adalah: ${YELLOW}${VPS_IP}${NC}"

    while true; do
        echo -n "[*] Mengecek A record untuk '${DOMAIN}'..."
        DOMAIN_IP=$(dig +short "$DOMAIN" A | head -n 1)
        echo ""
        if [ -z "$DOMAIN_IP" ]; then
            echo -e "${RED}[!] Gagal: Domain '${DOMAIN}' tidak memiliki A record.${NC}"
        elif [ "$VPS_IP" == "$DOMAIN_IP" ]; then
            echo -e "${GREEN}[OK] Berhasil! Domain '${DOMAIN}' sudah mengarah ke IP VPS ini.${NC}"
            break
        else
            echo -e "${RED}[!] GAGAL: Domain '${DOMAIN}' mengarah ke ${DOMAIN_IP}, bukan ke ${VPS_IP}.${NC}"
        fi
        read -p "$(echo -e ${YELLOW}"[?]"${NC}" [c]oba lagi validasi, atau [k]eluar? (c/k): ")" dns_choice
        if [[ "$dns_choice" =~ ^[Kk]$ ]]; then
            echo "[*] Skrip dihentikan."; exit 0;
        fi
    done

    # 3. Konfigurasi wajib untuk domain utama (root '/')
    declare -a location_configs
    print_title "LANGKAH 1: Konfigurasi Domain Utama ('/')"
    root_config=$(get_location_config "/")
    location_configs+=("$root_config")
    echo -e "${GREEN}[OK] Konfigurasi untuk lokasi root '/' disimpan.${NC}"

    # 4. Loop untuk penambahan route selanjutnya
    print_title "LANGKAH 2: Konfigurasi Rute Tambahan (Opsional)"
    while true; do
        read -p "$(echo -e ${YELLOW}"[?]"${NC}" Apakah Anda ingin menambahkan rute lain? (y/n): ")" add_route
        if [[ "$add_route" =~ ^[Nn]$ ]]; then
            echo "[*] Tidak ada rute tambahan. Melanjutkan..."; break
        elif [[ "$add_route" =~ ^[Yy]$ ]]; then
            while true; do
                read -p "    -> Masukkan path rute (diawali '/', contoh: /api): " route_path
                if [[ "$route_path" =~ ^/ ]]; then break
                else echo -e "${RED}[!] Path harus diawali '/'. Coba lagi.${NC}"; fi
            done
            sub_config=$(get_location_config "$route_path")
            location_configs+=("$sub_config")
            echo -e "${GREEN}[OK] Konfigurasi untuk rute '$route_path' disimpan.${NC}"
        else
            echo -e "${RED}[!] Jawaban tidak valid. Masukkan 'y' atau 'n'.${NC}"
        fi
    done

    # 5. Setup Nginx dan Certbot
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

    echo -e "\n${GREEN}===============================================================${NC}"
    echo -e "${GREEN}                        ✅ SETUP SELESAI ✅                      ${NC}"
    echo -e "         Domain ${YELLOW}https://$DOMAIN${NC} sekarang aktif.         "
    echo -e "${GREEN}===============================================================${NC}"
}