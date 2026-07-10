#!/bin/bash
# ==============================================================================
# bulfzf - TermX Core Engine (CLI & TUI)
# Version: 6.0.0-final (Menü İçi Catch & Canlı Log Akışı Eklendi)
# Description: Gelişmiş arama, hata ayıklama, terminal yönetimi ve öğretici sistem
# ==============================================================================

# --- Yapılandırma ---
CONFIG_DIR="$HOME/.config/termx"
FAV_FILE="$CONFIG_DIR/favoriler.txt"
LANG_FILE="$CONFIG_DIR/lang.cfg"
LOG_FILE="$CONFIG_DIR/termx.log"
TEMP_ERR="/tmp/termx_last_error.log"

# --- Dil Yükleme ---
LANG_PREF="EN"
[[ -f "$LANG_FILE" ]] && LANG_PREF=$(cat "$LANG_FILE")

if [[ "$LANG_PREF" == "TR" ]]; then
    UI_SEARCH="🔍 İçerik Ara"
    UI_ADD="➕ Favori Ekle"
    UI_DEL="🗑️ Favori Sil"
    UI_FILE_SEARCH="📂 Dosya Bul (fd)"
    UI_COMMAND_HELP="📘 Komut Yardımı (tldr)"
    UI_ERROR="🚨 Geçmiş Hata Analizi (Log Trap)"
    UI_CATCH="🎯 Canlı Komut İzleyici (Catch)"
    UI_LIVE_LOG="📡 Canlı Sistem Logları (Matriks Modu)"
    UI_TERMINAL="💻 Alt-Terminal Aç"
    UI_EXIT="❌ Çıkış"
    PROMPT_MAIN="⚡ TermX Ana Menü > "
    PROMPT_SEARCH_DIR="📂 Arama yapılacak dizini seç > "
    PROMPT_ADD="Eklenecek dizin: "
    PROMPT_DEL="Silinecek dizin: "
    MSG_ADDED="favorilere eklendi."
    MSG_DELETED="favorilerden silindi."
    MSG_DIR_MISSING="Dizin artık mevcut değil, listeden kaldırılıyor."
    MSG_HELP="Kullanım: bulfzf [add <yol> | search <yol> | error | catch <komut> | repair | --help]"
else
    # İngilizce varsayılanlar
    UI_SEARCH="🔍 Search Content"
    UI_ADD="➕ Add Favorite"
    UI_DEL="🗑️ Remove Favorite"
    UI_FILE_SEARCH="📂 Find Files (fd)"
    UI_COMMAND_HELP="📘 Command Help (tldr)"
    UI_ERROR="🚨 Past Error Analysis (Log Trap)"
    UI_CATCH="🎯 Live Command Catcher (Catch)"
    UI_LIVE_LOG="📡 Live System Logs (Tail)"
    UI_TERMINAL="💻 Open Sub-Terminal"
    UI_EXIT="❌ Exit"
    PROMPT_MAIN="⚡ TermX Main Menu > "
    PROMPT_SEARCH_DIR="📂 Select directory to search > "
    PROMPT_ADD="Enter path to add: "
    PROMPT_DEL="Select path to remove: "
    MSG_ADDED="added to favorites."
    MSG_DELETED="removed from favorites."
    MSG_DIR_MISSING="Directory no longer exists, removed from list."
    MSG_HELP="Usage: bulfzf [add <path> | search <path> | error | catch <command> | repair | --help]"
fi

# --- Varsayılan favoriler ---
if [[ ! -f "$FAV_FILE" ]]; then
    mkdir -p "$CONFIG_DIR"
    cat > "$FAV_FILE" <<EOF
$HOME
$PWD
/var/log
/etc
EOF
fi

# --- ÖĞRETİCİ BİLDİRİM SİSTEMİ ---
show_educational_tip() {
    if [[ "$LANG_PREF" == "TR" ]]; then
        local TIPS=(
            "💡 Öğretici: 'sudo' komutlarında şifre yazarken ekranda karakter görünmez. Bu Linux'un güvenlik önlemidir."
            "💡 Öğretici: Arama yaparken fzf ekranında CTRL+F'ye basarak listeyi anında tazeleyebilirsin."
            "💡 Öğretici: Bir servis çöküyorsa terminale çıkıp 'journalctl -xeu servis_adi' yazmak hayat kurtarır."
            "💡 Öğretici: 'tldr' (Komut Yardımı) sana uzun man sayfaları yerine sadece en çok kullanılan komut örneklerini verir."
            "💡 Öğretici: Arch Linux'ta pacman önbelleğini temizlemek ve yer açmak için 'sudo pacman -Scc' kullan."
            "💡 Öğretici: TermX'in Catch modunu test etmek istediğin her riskli işlemin başına koy."
            "💡 Öğretici: Linux'ta dosya izinlerini düzeltirken çalıştırma izni vermek için 'chmod +x dosya_adi' kullanılır."
        )
        local RANDOM_TIP="${TIPS[$RANDOM % ${#TIPS[@]}]}"
        
        if command -v notify-send &>/dev/null; then
            notify-send -u normal -a "TermX Asistan" -t 5000 "Eğitim Asistanı" "$RANDOM_TIP"
        fi
        
        echo -e "\n\033[0;33m$RANDOM_TIP\033[0m\n"
    fi
}

# --- Yardımcı: Sessiz Ekleme ---
silent_add() {
    local target=$(realpath "$1" 2>/dev/null)
    if [[ -d "$target" ]]; then
        if ! grep -Fxq "$target" "$FAV_FILE"; then
            echo "$target" >> "$FAV_FILE"
            echo -e "\033[0;32m✔ '$target' $MSG_ADDED\033[0m"
        fi
    else
        echo -e "\033[0;31m❌ $MSG_DIR_MISSING: $1\033[0m"
        read -p "Devam etmek için Enter'a basın..."
    fi
}

# --- Akıllı Arama Motoru ---
smart_search() {
    local target="$1"
    if [[ ! -d "$target" ]]; then
        echo -e "\033[0;31m$MSG_DIR_MISSING\033[0m"
        return
    fi
    local selected=$(rg --line-number --no-heading --color=always "" "$target" 2>/dev/null | \
        fzf --ansi --prompt="🔍 $target > " \
            --preview 'file=$(echo {} | cut -d: -f1); line=$(echo {} | cut -d: -f2); bat --style=numbers --color=always --highlight-line $line "$file"' \
            --preview-window='right:60%:wrap' \
            --bind 'ctrl-f:reload(fd . "'"$target"'" --type f | xargs rg --color=always --line-number "")' \
            --header 'ENTER: nano ile aç | CTRL-F: Yenile')
    if [[ -n "$selected" ]]; then
        local file=$(echo "$selected" | cut -d: -f1)
        local line=$(echo "$selected" | cut -d: -f2)
        nano +$line "$file"
    fi
}

# --- Dosya Bulucu ---
find_files() {
    local target="$1"
    [[ -z "$target" ]] && target="$HOME"
    local selected_file=$(fd . "$target" --type f | fzf --prompt="📂 Dosya ara > " --preview 'bat --color=always {}')
    [[ -n "$selected_file" ]] && nano "$selected_file"
}

# --- Komut Yardımı ---
command_help() {
    clear
    echo -e "\033[0;36m=== 📘 HIZLI KOMUT YARDIMI ===\033[0m"
    read -p "Nasıl kullanıldığını öğrenmek istediğin komutu yaz (Örn: tar, ls, grep): " cmd
    if [[ -n "$cmd" ]]; then
        if command -v tldr &>/dev/null; then
            tldr "$cmd" | less -R
        else
            echo "tldr yüklü değil, man sayfası açılıyor..."
            man "$cmd" 2>/dev/null || echo -e "\033[0;31mBu komut bulunamadı veya kılavuzu yok.\033[0m"
        fi
    fi
}

# --- HATA ANALİZ MOTORU (Geçmiş Loglar) ---
analyze_system_errors() {
    clear
    echo -e "\033[0;36mLoglar toplanıyor, lütfen bekleyin...\033[0m"
    {
        echo "=== [SİSTEM HATA KAYITLARI (journalctl)] ==="
        journalctl -p 3 -xb -n 40 --no-pager
        echo -e "\n=== [PACMAN KAYITLARI (pacman.log)] ==="
        grep -iE "error|fail" /var/log/pacman.log | tail -n 30
    } | rg -i --color=always "error|fail|warning|===" | \
      fzf --ansi --prompt="🚨 Log Analizi > " \
          --preview 'echo {}' \
          --preview-window='down:20%:wrap' \
          --layout=reverse --border --height=95% \
          --header 'Sadece kritik hatalar listeleniyor. Çıkmak için ESC/ENTER.'
}

# --- YENİ TERMİNAL AÇMA ---
open_terminal() {
    clear
    echo -e "\033[0;32m=== TermX Alt-Terminaline Geçildi ===\033[0m"
    echo -e "Burada istediğin komutu çalıştırabilirsin."
    echo -e "Menüye geri dönmek için \033[1;33mexit\033[0m yaz.\n"
    bash --login
}

# --- Favori Yönetimi ---
manage_favorites() {
    local choice=$(cat "$FAV_FILE" | fzf --prompt="$PROMPT_DEL" --height=15 --layout=reverse --border)
    if [[ -n "$choice" ]]; then
        sed -i "\|^$choice\$|d" "$FAV_FILE"
        echo -e "\033[0;32m✔ '$choice' $MSG_DELETED\033[0m"
        sleep 1
    fi
}

# ==============================================================================
# CLI PARAMETRE İŞLEYİCİ (Terminalden Direkt Kullanım)
# ==============================================================================
if [[ $# -gt 0 ]]; then
    case "$1" in
        add) silent_add "$2"; exit 0 ;;
        search) smart_search "${2:-$HOME}"; exit 0 ;;
        error|log) analyze_system_errors; exit 0 ;;
        catch)
            shift
            [[ -z "$1" ]] && { echo "İzlenecek komutu yazın. Örn: bulfzf catch sudo pacman -S paket"; exit 1; }
            > "$TEMP_ERR"
            echo -e "\033[0;33m⚡ TermX İzleme Modu Aktif: $@\033[0m"
            "$@" 2> >(tee "$TEMP_ERR" >/dev/tty)
            EXIT_CODE=$?
            if [[ $EXIT_CODE -ne 0 ]]; then
                sleep 1
                clear
                {
                    echo "=== [TERMX CANLI HATA YAKALAYICI] ==="
                    echo "Hatalı Komut : $@"
                    echo "Çıkış Kodu   : $EXIT_CODE"
                    echo -e "\n=== [SİSTEMİN GİZLEDİĞİ GERÇEK HATA] ==="
                    cat "$TEMP_ERR"
                } | fzf --ansi --color=bg+:#3b2224,hl+:#ff0000 \
                        --prompt="🚨 CANLI HATA YAKALANDI > " \
                        --layout=reverse --border=red --height=80% \
                        --header 'Bu hata havada yakalandı. Çıkmak için ESC/ENTER.'
            else
                echo -e "\n\033[0;32m✔ Komut sorunsuz tamamlandı.\033[0m"
            fi
            exit 0
            ;;
        *)
            [[ -d "$1" ]] && smart_search "$1" || echo -e "\033[0;31mGeçersiz komut. $MSG_HELP\033[0m"
            exit 1 ;;
    esac
fi

# ==============================================================================
# TUI ANA MENÜSÜ (Eksiksiz Döngü)
# ==============================================================================
while true; do
    clear
    show_educational_tip
    
    option=$(echo -e "$UI_SEARCH\n$UI_ADD\n$UI_DEL\n$UI_FILE_SEARCH\n$UI_COMMAND_HELP\n$UI_ERROR\n$UI_CATCH\n$UI_LIVE_LOG\n$UI_TERMINAL\n$UI_EXIT" | \
        fzf --prompt="$PROMPT_MAIN" --height=22 --layout=reverse --border --color=bg+:#2c323c,hl+:#e06c75)

    case "$option" in
        "$UI_SEARCH")
            target_dir=$(cat "$FAV_FILE" | fzf --prompt="$PROMPT_SEARCH_DIR" --height=15 --layout=reverse --border)
            [[ -n "$target_dir" ]] && smart_search "$target_dir"
            ;;
        "$UI_ADD")
            read -p "$PROMPT_ADD" new_dir
            new_dir="${new_dir/#\~/$HOME}"
            silent_add "$new_dir"
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
        "$UI_ERROR")
            analyze_system_errors
            ;;
        "$UI_CATCH")
            # --- MENÜ İÇİ CANLI HATA YAKALAYICI ---
            clear
            echo -e "\033[0;36m=== 🎯 CANLI KOMUT İZLEYİCİ ===\033[0m"
            read -p "Çalıştırılacak komutu yazın (Örn: ./cokus_test.sh veya ls -l): " catch_cmd
            if [[ -n "$catch_cmd" ]]; then
                > "$TEMP_ERR"
                echo -e "\033[0;33m⚡ İzleniyor: $catch_cmd\033[0m"
                # Komutu çalıştırıyoruz, hata varsa TEMP_ERR dosyasına aktarıyoruz
                eval "$catch_cmd" 2> >(tee "$TEMP_ERR" >/dev/tty)
                EXIT_CODE=$?
                if [[ $EXIT_CODE -ne 0 ]]; then
                    sleep 1
                    clear
                    {
                        echo "=== [TERMX CANLI HATA YAKALAYICI] ==="
                        echo "Hatalı Komut : $catch_cmd"
                        echo "Çıkış Kodu   : $EXIT_CODE"
                        echo -e "\n=== [SİSTEMİN GİZLEDİĞİ GERÇEK HATA] ==="
                        cat "$TEMP_ERR"
                    } | fzf --ansi --color=bg+:#3b2224,hl+:#ff0000 \
                            --prompt="🚨 HATA YAKALANDI > " \
                            --layout=reverse --border=red --height=80% \
                            --header 'TermX Kalkanı devrede! Çıkmak için ESC/ENTER.'
                else
                    echo -e "\n\033[0;32m✔ Komut sorunsuz tamamlandı.\033[0m"
                    read -p "Menüye dönmek için Enter'a basın..."
                fi
            fi
            ;;
        "$UI_LIVE_LOG")
            # --- MENÜ İÇİ CANLI LOG AKIŞI ---
            clear
            echo -e "\033[0;32m📡 Canlı loglar akıyor... (Çıkmak ve menüye dönmek için CTRL+C yapın)\033[0m"
            echo -e "----------------------------------------------------------------------"
            journalctl -f -n 15
            ;;
        "$UI_TERMINAL")
            open_terminal
            ;;
        "$UI_EXIT"|"")
            clear
            echo -e "\033[0;32mTermX'i kullandığın için teşekkürler. Görüşürüz!\033[0m"
            exit 0
            ;;
    esac
done
