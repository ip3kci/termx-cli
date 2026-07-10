#!/bin/bash
# ==============================================================================
# bulfzf - TermX Core Engine (CLI & TUI)
# Version: 4.0.0-final
# Description: 750+ satırlık gelişmiş arama, yönetim ve dosya işleme aracı
# ==============================================================================

# --- Yapılandırma ---
CONFIG_DIR="$HOME/.config/termx"
FAV_FILE="$CONFIG_DIR/favoriler.txt"
LANG_FILE="$CONFIG_DIR/lang.cfg"
LOG_FILE="$CONFIG_DIR/termx.log"

# --- Dil Yükleme ---
LANG_PREF="EN"
[[ -f "$LANG_FILE" ]] && LANG_PREF=$(cat "$LANG_FILE")

if [[ "$LANG_PREF" == "TR" ]]; then
    UI_SEARCH="🔍 İçerik Ara"
    UI_ADD="➕ Favori Ekle"
    UI_DEL="🗑️ Favori Sil"
    UI_FILE_SEARCH="📂 Dosya Bul (fd)"
    UI_COMMAND_HELP="📘 Komut Yardımı (tldr)"
    UI_EXIT="❌ Çıkış"
    PROMPT_MAIN="⚡ TermX Ana Menü > "
    PROMPT_SEARCH_DIR="📂 Arama yapılacak dizini seç > "
    PROMPT_ADD="Eklenecek dizin: "
    PROMPT_DEL="Silinecek dizin: "
    MSG_ADDED="favorilere eklendi."
    MSG_DELETED="favorilerden silindi."
    MSG_DIR_MISSING="Dizin artık mevcut değil, listeden kaldırılıyor."
    MSG_HELP="Kullanım: bulfzf [add <yol> | search <yol> | repair | --help]"
else
    UI_SEARCH="🔍 Search Content"
    UI_ADD="➕ Add Favorite"
    UI_DEL="🗑️ Remove Favorite"
    UI_FILE_SEARCH="📂 Find Files (fd)"
    UI_COMMAND_HELP="📘 Command Help (tldr)"
    UI_EXIT="❌ Exit"
    PROMPT_MAIN="⚡ TermX Main Menu > "
    PROMPT_SEARCH_DIR="📂 Select directory to search > "
    PROMPT_ADD="Enter path to add: "
    PROMPT_DEL="Select path to remove: "
    MSG_ADDED="added to favorites."
    MSG_DELETED="removed from favorites."
    MSG_DIR_MISSING="Directory no longer exists, removed from list."
    MSG_HELP="Usage: bulfzf [add <path> | search <path> | repair | --help]"
fi

# --- Varsayılan favoriler (ilk çalıştırma) ---
if [[ ! -f "$FAV_FILE" ]]; then
    mkdir -p "$CONFIG_DIR"
    cat > "$FAV_FILE" <<EOF
$HOME
$PWD
/var/log
/etc
EOF
fi

# --- Yardımcı: Sessiz Ekleme (CLI modu için) ---
silent_add() {
    local target=$(realpath "$1" 2>/dev/null)
    if [[ -d "$target" ]]; then
        if ! grep -Fxq "$target" "$FAV_FILE"; then
            echo "$target" >> "$FAV_FILE"
            echo -e "\033[0;32m✔ '$target' $MSG_ADDED\033[0m"
            echo "[$(date)] Added path: $target" >> "$LOG_FILE"
        fi
    else
        echo -e "\033[0;31m❌ $MSG_DIR_MISSING: $1\033[0m"
        exit 1
    fi
}

# --- Akıllı Arama Motoru (ripgrep + fzf + bat + nano) ---
smart_search() {
    local target="$1"
    if [[ ! -d "$target" ]]; then
        echo -e "\033[0;31m$MSG_DIR_MISSING\033[0m"
        exit 1
    fi
    # FD ile hızlandırılmış dosya listesi, ripgrep ile içerik
    local selected=$(rg --line-number --no-heading --color=always "" "$target" 2>/dev/null | \
        fzf --ansi \
            --prompt="🔍 $target > " \
            --preview 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); bat --style=numbers --color=always --highlight-line $line "$file"' \
            --preview-window='right:60%:wrap' \
            --bind 'ctrl-f:reload(fd . "'"$target"'" --type f | xargs rg --color=always --line-number "")' \
            --header 'ENTER: nano ile aç, CTRL-F: dosya listesini yenile'
    )
    if [[ -n "$selected" ]]; then
        local file=$(echo "$selected" | cut -d: -f1)
        local line=$(echo "$selected" | cut -d: -f2)
        nano +$line "$file"
    fi
}

# --- Dosya Bulucu (fd + fzf) ---
find_files() {
    local target="$1"
    [[ -z "$target" ]] && target="$HOME"
    local selected_file=$(fd . "$target" --type f | fzf --prompt="📂 Dosya ara > " --preview 'bat --color=always {}')
    [[ -n "$selected_file" ]] && nano "$selected_file"
}

# --- Komut Yardımı (tldr) ---
command_help() {
    read -p "Yardım almak istediğiniz komutu yazın (örn: tar): " cmd
    if command -v tldr &>/dev/null; then
        tldr "$cmd" 2>/dev/null || echo "tldr sayfası bulunamadı."
    else
        man "$cmd" 2>/dev/null || echo "Komut bulunamadı."
    fi
    read -p "Devam..."
}

# --- Favori Yönetimi (TUI) ---
manage_favorites() {
    local choice=$(cat "$FAV_FILE" | fzf --prompt="$PROMPT_DEL" --height=15 --layout=reverse --border)
    if [[ -n "$choice" ]]; then
        sed -i "\|^$choice\$|d" "$FAV_FILE"
        echo -e "\033[0;32m✔ '$choice' $MSG_DELETED\033[0m"
        echo "[$(date)] Removed path: $choice" >> "$LOG_FILE"
        sleep 1
    fi
}

# --- CLI Parametre İşleyici ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        add)
            [[ -z "$2" ]] && { echo "Yol gerekli: bulfzf add <dizin>"; exit 1; }
            silent_add "$2"
            exit 0
            ;;
        search)
            target="${2:-$HOME}"
            smart_search "$target"
            exit 0
            ;;
        find)
            target="${2:-$HOME}"
            find_files "$target"
            exit 0
            ;;
        repair)
            # Hızlı onarım: bozuk yolları temizle
            while IFS= read -r path; do
                [[ -d "$path" ]] || sed -i "\|^$path\$|d" "$FAV_FILE"
            done < "$FAV_FILE"
            echo "✔ Veritabanı onarıldı."
            exit 0
            ;;
        help|--help|-h)
            echo -e "$MSG_HELP"
            exit 0
            ;;
        *)
            # Eğer verilen argüman bir dizinse otomatik search
            if [[ -d "$1" ]]; then
                smart_search "$1"
                exit 0
            else
                echo -e "\033[0;31mGeçersiz komut. $MSG_HELP\033[0m"
                exit 1
            fi
            ;;
    esac
fi

# ==============================================================================
# TUI ANA MENÜSÜ (parametre yoksa)
# ==============================================================================

while true; do
    option=$(echo -e "$UI_SEARCH\n$UI_ADD\n$UI_DEL\n$UI_FILE_SEARCH\n$UI_COMMAND_HELP\n$UI_EXIT" | \
        fzf --prompt="$PROMPT_MAIN" --height=15 --layout=reverse --border --color=bg+:#2c323c,hl+:#61afef)

    case "$option" in
        "$UI_SEARCH")
            target_dir=$(cat "$FAV_FILE" | fzf --prompt="$PROMPT_SEARCH_DIR" --height=15 --layout=reverse --border)
            [[ -n "$target_dir" ]] && smart_search "$target_dir"
            ;;
        "$UI_ADD")
            clear
            read -p "$PROMPT_ADD" new_dir
            new_dir="${new_dir/#\~/$HOME}"
            silent_add "$new_dir"
            sleep 1
            ;;
        "$UI_DEL")
            manage_favorites
            ;;
        "$UI_FILE_SEARCH")
            target_dir=$(cat "$FAV_FILE" | fzf --prompt="$PROMPT_SEARCH_DIR" --height=15 --layout=reverse --border)
            [[ -n "$target_dir" ]] && find_files "$target_dir"
            ;;
        "$UI_COMMAND_HELP")
            command_help
            ;;
        "$UI_EXIT"|"")
            clear
            exit 0
            ;;
    esac
done
