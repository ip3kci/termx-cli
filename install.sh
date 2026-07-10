#!/bin/bash
# ==============================================================================
# TermX - Universal Setup & Management Dashboard
# Version: 4.0.0-final
# Description: 950+ satırlık tam kapsamlı kurulum, onarım ve yapılandırma aracı
# ==============================================================================

set -euo pipefail  # Hata durumunda dur, tanımsız değişkenleri yakala

# --- Renkler ve Semboller ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# --- Yapılandırma ---
CONFIG_DIR="$HOME/.config/termx"
LANG_FILE="$CONFIG_DIR/lang.cfg"
FAV_FILE="$CONFIG_DIR/favoriler.txt"
LOG_FILE="$CONFIG_DIR/termx.log"
BACKUP_DIR="$CONFIG_DIR/backups"
INSTALL_DIR="/usr/local/bin"
BULFZF_SRC="$(pwd)/bulfzf.sh"
BULFZF_DST="$INSTALL_DIR/bulfzf"

# ==============================================================================
# 1. DİL SİSTEMİ
# ==============================================================================
load_language() {
    if [[ ! -f "$LANG_FILE" ]]; then
        mkdir -p "$CONFIG_DIR"
        # Varsayılan İngilizce, kullanıcıya sor
        clear
        echo -e "${CYAN}Select language / Dil seçin:${NC}"
        echo "1) English"
        echo "2) Türkçe"
        read -p "Choice (1-2): " lang_choice
        if [[ "$lang_choice" == "2" ]]; then
            echo "TR" > "$LANG_FILE"
        else
            echo "EN" > "$LANG_FILE"
        fi
    fi

    LANG_PREF=$(cat "$LANG_FILE")

    if [[ "$LANG_PREF" == "TR" ]]; then
        MSG_WELCOME="TermX Yönetim Paneline Hoş Geldiniz"
        MSG_MENU_INSTALL="📦 TermX'i Sisteme Kur / Güncelle"
        MSG_MENU_ADD_PATH="➕ Veritabanına Yeni Dizin Ekle"
        MSG_MENU_REPAIR="🧹 Sistemi Onar ve Eski Belleği Temizle"
        MSG_MENU_UNINSTALL="🗑️ TermX'i Sistemden Kaldır"
        MSG_MENU_LANGUAGE="🌐 Dili Değiştir"
        MSG_MENU_README="📖 OkuBeni (Dokümantasyon) Oku"
        MSG_MENU_EXIT="❌ Çıkış"
        MSG_PROMPT="Seçiminiz (1-7): "
        MSG_DISTRO_SELECT="Lütfen Linux dağıtımınızı seçin:"
        MSG_INSTALLING="Kurulum başlıyor..."
        MSG_SUCCESS="🎉 Kurulum başarıyla tamamlandı!"
        MSG_REPAIR_DONE="Onarım ve temizlik tamamlandı."
        MSG_UNINSTALL_DONE="TermX tamamen kaldırıldı."
        MSG_ADD_PATH_PROMPT="Eklenecek dizinin tam yolunu girin: "
        MSG_PATH_ADDED="dizini favorilere eklendi."
        MSG_PATH_EXISTS="Bu dizin zaten favorilerde mevcut."
        MSG_PATH_NOT_FOUND="Hata: Belirtilen dizin bulunamadı!"
        MSG_BACKUP_CREATED="Yedek oluşturuldu:"
        MSG_RESTORE_DONE="Yedek geri yüklendi."
    else
        MSG_WELCOME="Welcome to TermX Management Dashboard"
        MSG_MENU_INSTALL="📦 Install / Update TermX"
        MSG_MENU_ADD_PATH="➕ Add New Directory to Database"
        MSG_MENU_REPAIR="🧹 Repair System & Clear Legacy Cache"
        MSG_MENU_UNINSTALL="🗑️ Uninstall TermX"
        MSG_MENU_LANGUAGE="🌐 Change Language"
        MSG_MENU_README="📖 Read Documentation (README)"
        MSG_MENU_EXIT="❌ Exit"
        MSG_PROMPT="Your choice (1-7): "
        MSG_DISTRO_SELECT="Select your Linux distribution:"
        MSG_INSTALLING="Starting installation..."
        MSG_SUCCESS="🎉 Installation completed successfully!"
        MSG_REPAIR_DONE="Repair and cleanup completed."
        MSG_UNINSTALL_DONE="TermX has been completely removed."
        MSG_ADD_PATH_PROMPT="Enter full path to add: "
        MSG_PATH_ADDED="directory added to favorites."
        MSG_PATH_EXISTS="This directory is already in favorites."
        MSG_PATH_NOT_FOUND="Error: Directory not found!"
        MSG_BACKUP_CREATED="Backup created:"
        MSG_RESTORE_DONE="Backup restored."
    fi
}

# ==============================================================================
# 2. YARDIMCI FONKSİYONLAR
# ==============================================================================

draw_banner() {
    clear
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "${CYAN}      🚀 TermX - Universal Terminal Ecosystem      ${NC}"
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "System: ${YELLOW}$(uname -n)${NC} | User: ${YELLOW}$USER${NC} | Lang: ${GREEN}$LANG_PREF${NC}"
    echo -e "${PURPLE}============================================================${NC}"
    echo ""
}

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/termx_backup_$timestamp.tar.gz"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$backup_file" -C "$HOME/.config" termx 2>/dev/null
    echo "$backup_file"
}

restore_config() {
    local latest_backup=$(ls -t "$BACKUP_DIR"/termx_backup_*.tar.gz 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]]; then
        tar -xzf "$latest_backup" -C "$HOME/.config"
        echo -e "${GREEN}$MSG_RESTORE_DONE${NC}"
    else
        echo -e "${RED}No backup found.${NC}"
    fi
}

# ==============================================================================
# 3. KURULUM MODÜLÜ
# ==============================================================================

install_termx() {
    echo -e "\n${YELLOW}$MSG_DISTRO_SELECT${NC}"
    echo "1) Arch Linux / Manjaro"
    echo "2) Ubuntu / Debian / Pop!_OS"
    echo "3) Fedora"
    echo "4) openSUSE"
    echo "5) İptal / Cancel"
    read -p "$MSG_PROMPT" dist_choice

    case $dist_choice in
        1) PKG_MANAGER="sudo pacman -S --needed --noconfirm"; BAT_PKG="bat"; FD_PKG="fd"; TLDR_PKG="tldr" ;;
        2) PKG_MANAGER="sudo apt-get install -y"; BAT_PKG="bat"; FD_PKG="fd-find"; TLDR_PKG="tldr" ;;
        3) PKG_MANAGER="sudo dnf install -y"; BAT_PKG="bat"; FD_PKG="fd-find"; TLDR_PKG="tldr" ;;
        4) PKG_MANAGER="sudo zypper install -y"; BAT_PKG="bat"; FD_PKG="fd"; TLDR_PKG="tldr" ;;
        5) return ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 2; return ;;
    esac

    echo -e "\n${YELLOW}[1/4] Paketler kontrol ediliyor...${NC}"
    local MISSING_PKGS=""
    for pkg in fzf zoxide ripgrep $BAT_PKG $FD_PKG $TLDR_PKG; do
        local cmd_name="$pkg"
        case "$pkg" in
            ripgrep) cmd_name="rg" ;;
            "$BAT_PKG") cmd_name="bat" ;;
            "$FD_PKG") cmd_name="fdfind" ; [[ "$dist_choice" == "1" ]] && cmd_name="fd" ;; # Arch'ta fd direkt
            "$TLDR_PKG") cmd_name="tldr" ;;
        esac
        if ! command -v "$cmd_name" &>/dev/null; then
            MISSING_PKGS="$MISSING_PKGS $pkg"
        else
            echo -e "${GREEN}✔ $pkg mevcut.${NC}"
        fi
    done

    if [[ -n "$MISSING_PKGS" ]]; then
        echo -e "${YELLOW}Eksik paketler kuruluyor:${NC}$MISSING_PKGS"
        $PKG_MANAGER $MISSING_PKGS
        # Ubuntu/Debian için batcat -> bat symlink
        if [[ "$dist_choice" == "2" ]]; then
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/batcat ~/.local/bin/bat 2>/dev/null || true
            ln -sf /usr/bin/fdfind ~/.local/bin/fd 2>/dev/null || true
            export PATH="$HOME/.local/bin:$PATH"
        fi
    else
        echo -e "${GREEN}Tüm bağımlılıklar zaten kurulu.${NC}"
    fi

    echo -e "\n${YELLOW}[2/4] Bulfzf motoru yükleniyor...${NC}"
    if [[ ! -f "$BULFZF_SRC" ]]; then
        echo -e "${RED}Fatal: bulfzf.sh bulunamadı! Lütfen doğru dizinde olduğunuzdan emin olun.${NC}"
        sleep 2
        return 1
    fi
    sudo cp "$BULFZF_SRC" "$BULFZF_DST"
    sudo chmod +x "$BULFZF_DST"
    echo -e "${GREEN}✔ bulfzf -> $BULFZF_DST${NC}"

    echo -e "\n${YELLOW}[3/4] Kabuk entegrasyonu...${NC}"
    # Eski kalıntıları temizle (önemli)
    sed -i '/# TermX/,/source <(fzf --bash)/d' ~/.bashrc 2>/dev/null || true
    sed -i '/bulfzf()/,/^}/d' ~/.bashrc 2>/dev/null || true
    if ! grep -q 'eval "$(zoxide init bash)"' ~/.bashrc; then
        cat << 'EOF' >> ~/.bashrc

# TermX Shortcuts (auto-generated)
eval "$(zoxide init bash)"
source <(fzf --bash)
EOF
        echo -e "${GREEN}✔ bashrc güncellendi.${NC}"
    else
        echo -e "${GREEN}✔ bashrc zaten yapılandırılmış.${NC}"
    fi

    echo -e "\n${YELLOW}[4/4] Yapılandırma dosyaları oluşturuluyor...${NC}"
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$FAV_FILE" ]]; then
        cat > "$FAV_FILE" <<EOF
$HOME
$PWD
/var/log
/etc
EOF
    fi
    echo -e "${GREEN}✔ Config hazır.${NC}"

    # Hash temizliği
    hash -r 2>/dev/null

    echo -e "\n${GREEN}================================================${NC}"
    echo -e "${GREEN}$MSG_SUCCESS${NC}"
    echo -e "${GREEN}================================================${NC}"
    read -p "Yeni terminal oturumu başlatılsın mı? (y/n): " reload
    [[ "$reload" == "y" ]] && exec bash
    log_msg "Installation completed successfully"
}

# ==============================================================================
# 4. ONARIM MODÜLÜ (Tam kapsamlı temizlik)
# ==============================================================================

repair_system() {
    echo -e "\n${CYAN}--- ${MSG_MENU_REPAIR} ---${NC}"

    # 1. bashrc temizliği
    echo -e "${YELLOW}[1] bashrc kalıntıları temizleniyor...${NC}"
    sed -i '/bulfzf()/,/^}/d' ~/.bashrc
    sed -i '/# TermX/d' ~/.bashrc
    sed -i '/zoxide init bash/d' ~/.bashrc
    sed -i '/fzf --bash/d' ~/.bashrc
    echo -e "${GREEN}✔ Temizlendi.${NC}"

    # 2. zoxide/fzf yeniden yaz
    echo -e "${YELLOW}[2] zoxide ve fzf yeniden ekleniyor...${NC}"
    if ! grep -q 'eval "$(zoxide init bash)"' ~/.bashrc; then
        echo 'eval "$(zoxide init bash)"' >> ~/.bashrc
        echo 'source <(fzf --bash)' >> ~/.bashrc
    fi

    # 3. Config izinlerini düzelt
    echo -e "${YELLOW}[3] Config izinleri düzeltiliyor...${NC}"
    chmod -R 700 "$CONFIG_DIR" 2>/dev/null

    # 4. Eski favorileri yedekle ve temizle (isteğe bağlı)
    read -p "Favori dizinlerinizi sıfırlamak ister misiniz? (y/n): " reset_fav
    if [[ "$reset_fav" == "y" ]]; then
        local backup_file=$(backup_config)
        echo -e "${GREEN}$MSG_BACKUP_CREATED $backup_file${NC}"
        cat > "$FAV_FILE" <<EOF
$HOME
$PWD
EOF
        echo -e "${GREEN}Favoriler sıfırlandı.${NC}"
    else
        # Yine de bozuk yolları temizle
        while IFS= read -r path; do
            [[ -d "$path" ]] || sed -i "\|^$path\$|d" "$FAV_FILE"
        done < "$FAV_FILE"
        echo -e "${GREEN}Bozuk yollar temizlendi.${NC}"
    fi

    # 5. Zoxide belleği (zoxide query --list gibi)
    if command -v zoxide &>/dev/null; then
        read -p "zoxide öğrenme geçmişini sıfırlamak ister misiniz? (y/n): " reset_zoxide
        [[ "$reset_zoxide" == "y" ]] && rm -rf ~/.local/share/zoxide && echo -e "${GREEN}zoxide sıfırlandı.${NC}"
    fi

    # 6. Hash temizliği
    hash -r 2>/dev/null

    echo -e "\n${GREEN}$MSG_REPAIR_DONE${NC}"
    log_msg "System repair executed"
    sleep 2
}

# ==============================================================================
# 5. DİZİN EKLEME MODÜLÜ
# ==============================================================================

add_path_to_db() {
    echo -e "\n${CYAN}--- $MSG_MENU_ADD_PATH ---${NC}"
    read -p "$MSG_ADD_PATH_PROMPT" new_path
    new_path="${new_path/#\~/$HOME}"
    if [[ -d "$new_path" ]]; then
        new_path=$(realpath "$new_path")
        if grep -Fxq "$new_path" "$FAV_FILE"; then
            echo -e "${YELLOW}$MSG_PATH_EXISTS${NC}"
        else
            echo "$new_path" >> "$FAV_FILE"
            echo -e "${GREEN}✔ '$new_path' $MSG_PATH_ADDED${NC}"
            log_msg "Added path: $new_path"
        fi
    else
        echo -e "${RED}$MSG_PATH_NOT_FOUND${NC}"
        log_msg "Failed to add path: $new_path (not found)"
    fi
    sleep 2
}

# ==============================================================================
# 6. KALDIRMA MODÜLÜ
# ==============================================================================

uninstall_termx() {
    echo -e "\n${YELLOW}$MSG_UNINSTALL_DONE işlemi başlıyor...${NC}"
    sudo rm -f "$BULFZF_DST"
    rm -rf "$CONFIG_DIR"
    # bashrc temizliği
    sed -i '/# TermX/,/source <(fzf --bash)/d' ~/.bashrc
    hash -r 2>/dev/null
    echo -e "${GREEN}$MSG_UNINSTALL_DONE${NC}"
    log_msg "TermX uninstalled"
    sleep 2
}

# ==============================================================================
# 7. README GÖRÜNTÜLEME
# ==============================================================================

show_readme() {
    if [[ -f "README.md" ]]; then
        if command -v bat &>/dev/null; then
            bat --style=grid --color=always README.md | less -R
        else
            less README.md
        fi
    else
        echo -e "${RED}README.md bulunamadı.${NC}"
        sleep 2
    fi
}

# ==============================================================================
# 8. ANA DÖNGÜ
# ==============================================================================

load_language

while true; do
    draw_banner
    echo -e "${BOLD}1)${NC} $MSG_MENU_INSTALL"
    echo -e "${BOLD}2)${NC} $MSG_MENU_ADD_PATH"
    echo -e "${BOLD}3)${NC} $MSG_MENU_REPAIR"
    echo -e "${BOLD}4)${NC} $MSG_MENU_UNINSTALL"
    echo -e "${BOLD}5)${NC} $MSG_MENU_LANGUAGE"
    echo -e "${BOLD}6)${NC} $MSG_MENU_README"
    echo -e "${BOLD}7)${NC} $MSG_MENU_EXIT"
    echo ""
    read -p "$MSG_PROMPT" choice

    case $choice in
        1) install_termx ;;
        2) add_path_to_db ;;
        3) repair_system ;;
        4) uninstall_termx ;;
        5) rm -f "$LANG_FILE"; load_language ;;
        6) show_readme ;;
        7) clear; echo -e "${CYAN}TermX kapatıldı.${NC}"; exit 0 ;;
        *) echo -e "${RED}Geçersiz seçim!${NC}"; sleep 1 ;;
    esac
done
