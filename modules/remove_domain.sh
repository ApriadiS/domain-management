#!/bin/bash
#================================================================================#
# Skrip Hapus Domain
# - Dijalankan sebagai modul dari domain_manager.sh
# - Semua fungsi bantu diimpor dari skrip utama.
#================================================================================#

# Fungsi utama untuk menghapus domain
function main_remove() {
    local clean_mode=0
    if [[ "$1" == "--clean" ]]; then
        clean_mode=1
    fi

    clear
    print_title "Selamat Datang di Skrip Hapus Domain"
    
    # Jalankan Health Check
    health_check

    # Temukan dan daftarkan hanya domain yang SEHAT (available dan enabled)
    declare -a healthy_domains
    for domain in $(ls /etc/nginx/sites-enabled 2>/dev/null | grep -v "default"); do
        if [ -f "/etc/nginx/sites-available/$domain" ]; then
            healthy_domains+=("$domain")
        fi
    done

    if [ ${#healthy_domains[@]} -eq 0 ]; then
        echo "Informasi: Tidak ada domain aktif yang bisa dihapus."
        exit 0
    fi

    print_title "Pilih Domain Aktif untuk Dihapus"
    for i in "${!healthy_domains[@]}"; do
        echo "  [${YELLOW}$((i+1))${NC}] ${healthy_domains[$i]}"
    done
    echo "  [${YELLOW}0${NC}] Batal"
    echo ""

    while true; do
        read -p "$(echo -e ${YELLOW}"[?]"${NC}" Masukkan nomor: ")" CHOICE
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -gt ${#healthy_domains[@]} ]; then
            echo -e "${RED}[!] Input tidak valid.${NC}"
        else
            break
        fi
    done

    if [ "$CHOICE" -eq 0 ]; then
        echo "[*] Proses dibatalkan."
        exit 0
    fi

    SELECTED_DOMAIN="${healthy_domains[$((CHOICE-1))]}"

    print_title "KONFIRMASI PENGHAPUSAN: $SELECTED_DOMAIN"
    echo -e "Anda akan menghapus domain ${YELLOW}${SELECTED_DOMAIN}${NC} secara permanen."
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" Ketik '${RED}yes${NC}' untuk konfirmasi: " CONFIRMATION

    if [ "$CONFIRMATION" != "yes" ]; then
        echo "[*] Konfirmasi tidak cocok. Dibatalkan."
        exit 0
    fi

    print_title "MEMULAI PROSES PEMBERSIHAN UNTUK: $SELECTED_DOMAIN"
    NGINX_SYMLINK="/etc/nginx/sites-enabled/$SELECTED_DOMAIN"
    NGINX_CONF="/etc/nginx/sites-available/$SELECTED_DOMAIN"
    run_silent "Menghapus sertifikat SSL" "certbot delete --cert-name '$SELECTED_DOMAIN' --non-interactive"
    run_silent "Menonaktifkan situs" "rm -f '$NGINX_SYMLINK'"
    run_silent "Menghapus konfigurasi Nginx" "rm -f '$NGINX_CONF'"

    if [ $clean_mode -eq 1 ]; then
        run_silent "Menghapus file konfigurasi cadangan" "rm -f /etc/nginx/sites-available/${SELECTED_DOMAIN}.bak"
        run_silent "Menghapus file konfigurasi cadangan .save" "rm -f /etc/nginx/sites-available/${SELECTED_DOMAIN}.save"
    fi

    run_silent "Menguji konfigurasi Nginx" "nginx -t"
    run_silent "Me-reload Nginx" "systemctl reload nginx"

    echo -e "\n${GREEN}===============================================================${NC}"
    if [ $clean_mode -eq 1 ]; then
        echo -e "${GREEN} ✅ PENGHAPUSAN BERSIH SELESAI ✅ "
    else
        echo -e "${GREEN} ✅ PENGHAPUSAN STANDAR SELESAI ✅ "
    fi
    echo -e "       Domain ${YELLOW}$SELECTED_DOMAIN${NC} telah dihapus sepenuhnya.       "
    echo -e "${GREEN}===============================================================${NC}"
}

# Fungsi untuk memeriksa sinkronisasi konfigurasi (Health Check)
function health_check() {
    print_title "HEALTH CHECK: Memeriksa Sinkronisasi Konfigurasi"
    echo -n "[*] Mengumpulkan data konfigurasi Nginx dan Certbot..."
    mapfile -t AVAIL < <(ls /etc/nginx/sites-available 2>/dev/null | grep -v "default" | grep -v "\.save$" | grep -v "\.bak$")
    mapfile -t ENABLED < <(ls /etc/nginx/sites-enabled 2>/dev/null | grep -v "default")
    mapfile -t CERTS < <(certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}')
    echo -e " ${GREEN}Selesai.${NC}"
    declare -a orphans_config orphans_cert broken_links
    for domain in "${AVAIL[@]}"; do [[ " ${ENABLED[*]} " =~ " ${domain} " ]] || orphans_config+=("$domain"); done
    for domain in "${ENABLED[@]}"; do [ ! -f "/etc/nginx/sites-available/$domain" ] && broken_links+=("$domain"); done
    for domain in "${CERTS[@]}"; do [[ " ${AVAIL[*]} " =~ " ${domain} " ]] || orphans_cert+=("$domain"); done
    if [ ${#orphans_config[@]} -eq 0 ] && [ ${#broken_links[@]} -eq 0 ] && [ ${#orphans_cert[@]} -eq 0 ]; then echo -e "${GREEN}[OK] Semua konfigurasi sinkron.${NC}"; return; fi
    echo -e "${YELLOW}[!] Ditemukan beberapa inkonsistensi pada server Anda:${NC}"
    if [ ${#orphans_config[@]} -gt 0 ]; then echo "  - Konfigurasi Tidak Aktif (yatim):"; for domain in "${orphans_config[@]}"; do echo -e "    ${RED}- $domain${NC}"; done; fi
    if [ ${#broken_links[@]} -gt 0 ]; then echo "  - Link Rusak (tidak ada file asli):"; for domain in "${broken_links[@]}"; do echo -e "    ${RED}- $domain${NC}"; done; fi
    if [ ${#orphans_cert[@]} -gt 0 ]; then echo "  - Sertifikat SSL Tidak Digunakan (yatim):"; for domain in "${orphans_cert[@]}"; do echo -e "    ${RED}- $domain${NC}"; done; fi
    echo ""
    read -p "$(echo -e ${YELLOW}"[?]"${NC}" Apakah Anda ingin membersihkan inkonsistensi ini sekarang? (y/n): ")" cleanup_choice
    if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
        print_title "MEMBERSIHKAN RESIDU"
        for domain in "${orphans_config[@]}"; do run_silent "Menghapus config yatim: $domain" "rm -f /etc/nginx/sites-available/$domain"; done
        for domain in "${broken_links[@]}"; do run_silent "Menghapus link rusak: $domain" "rm -f /etc/nginx/sites-enabled/$domain"; done
        for domain in "${orphans_cert[@]}"; do run_silent "Menghapus sertifikat yatim: $domain" "certbot delete --cert-name '$domain' --non-interactive"; done
        run_silent "Me-reload Nginx setelah pembersihan" "systemctl reload nginx"
    else
        echo "[*] Melewatkan pembersihan. Hanya akan menampilkan domain yang aktif dan sehat."
    fi
}