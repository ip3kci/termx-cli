#!/bin/bash
# ==============================================================================
# bulfzf_cleaner.sh - Eski bulfzf kalıntılarını tamamen temizler
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Eski bulfzf kalıntıları taranıyor...${NC}"

# Taranacak dosyaların listesi
FILES=(
    "$HOME/.bashrc"
    "$HOME/.profile"
    "$HOME/.bash_profile"
    "$HOME/.bash_aliases"
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.config/fish/config.fish"
)

CLEANED=0

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        # Eski bulfzf fonksiyonu var mı?
        if grep -q 'bulfzf()' "$file" 2>/dev/null; then
            echo -e "${RED}Bulundu: $file içinde bulfzf() fonksiyonu${NC}"
            # Fonksiyonu tamamen sil (başlangıcından bitişine kadar)
            sed -i '/bulfzf()/,/^}/d' "$file"
            echo -e "${GREEN}  -> Temizlendi.${NC}"
            CLEANED=1
        fi

        # Eski alias var mı?
        if grep -q 'alias.*bulfzf' "$file" 2>/dev/null; then
            echo -e "${RED}Bulundu: $file içinde alias bulfzf${NC}"
            sed -i '/alias.*bulfzf/d' "$file"
            echo -e "${GREEN}  -> Alias silindi.${NC}"
            CLEANED=1
        fi

        # TermX ile ilgili satırlar (zoxide/fzf entegrasyonu da dahil)
        if grep -q '# TermX' "$file" 2>/dev/null; then
            echo -e "${YELLOW}Bulundu: $file içinde # TermX satırları${NC}"
            sed -i '/# TermX/d' "$file"
            # Hemen altındaki zoxide/fzf satırlarını da temizle (isteğe bağlı)
            sed -i '/eval.*zoxide init bash/d' "$file"
            sed -i '/source.*fzf --bash/d' "$file"
            echo -e "${GREEN}  -> TermX satırları silindi.${NC}"
            CLEANED=1
        fi
    fi
done

if [[ $CLEANED -eq 1 ]]; then
    echo -e "\n${GREEN}Tüm eski kalıntılar başarıyla temizlendi.${NC}"
else
    echo -e "\n${YELLOW}Hiçbir eski kalıntı bulunamadı. Sistem zaten temiz.${NC}"
fi

# Şimdi taze bir bulfzf kurulumu için hatırlatma
echo -e "\n${YELLOW}Şimdi yapmanız gerekenler:${NC}"
echo "1. Yeni bulfzf binary'sini kurmak için:"
echo "   sudo cp bulfzf.sh /usr/local/bin/bulfzf && sudo chmod +x /usr/local/bin/bulfzf"
echo "2. Veya install.sh ile tam kurulum yapın:"
echo "   ./install.sh   (menüden 1'i seçin)"
echo "3. Terminali kapatıp açın veya 'exec bash' yazın."
