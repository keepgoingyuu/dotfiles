#!/bin/bash
# ============================================
# Dotfiles 一鍵部署腳本
# 用法: git clone <repo> ~/dotfiles && cd ~/dotfiles && ./install.sh
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# ============================================
# 備份既有設定
# ============================================
backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/"
        warn "已備份: $target → $BACKUP_DIR/"
    fi
}

# ============================================
# 安裝基礎套件
# ============================================
install_packages() {
    info "安裝基礎套件..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        zsh git curl wget unzip build-essential \
        tmux fzf zoxide stow ripgrep fd-find \
        openssh-server
    success "基礎套件安裝完成"
}

# ============================================
# 安裝 Oh My Zsh + 插件
# ============================================
install_ohmyzsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        info "安裝 Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Oh My Zsh 安裝完成"
    else
        success "Oh My Zsh 已存在，跳過"
    fi

    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh plugins
    [ -d "$custom/plugins/zsh-autosuggestions" ] || \
        git clone https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
    [ -d "$custom/plugins/zsh-syntax-highlighting" ] || \
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"
    [ -d "$custom/plugins/zsh-completions" ] || \
        git clone https://github.com/zsh-users/zsh-completions "$custom/plugins/zsh-completions"

    success "Zsh 插件安裝完成"
}

# ============================================
# 安裝 NVM + Node.js
# ============================================
install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        info "安裝 NVM..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        success "NVM + Node.js LTS 安裝完成"
    else
        success "NVM 已存在，跳過"
    fi
}

# ============================================
# 安裝 Go
# ============================================
install_go() {
    if ! command -v go &>/dev/null; then
        info "安裝 Go..."
        local go_version="1.23.5"
        local arch
        arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
        curl -sLO "https://go.dev/dl/go${go_version}.linux-${arch}.tar.gz"
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go${go_version}.linux-${arch}.tar.gz"
        rm -f "go${go_version}.linux-${arch}.tar.gz"
        export PATH="/usr/local/go/bin:$PATH"
        success "Go ${go_version} 安裝完成"
    else
        success "Go 已存在: $(go version)"
    fi
}

# ============================================
# 安裝 Starship prompt
# ============================================
install_starship() {
    if ! command -v starship &>/dev/null; then
        info "安裝 Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        success "Starship 安裝完成"
    else
        success "Starship 已存在"
    fi
}

# ============================================
# 安裝 sesh (tmux session manager)
# ============================================
install_sesh() {
    if ! command -v sesh &>/dev/null; then
        info "安裝 sesh..."
        go install github.com/joshmedeski/sesh@latest
        success "sesh 安裝完成"
    else
        success "sesh 已存在"
    fi
}

# ============================================
# 安裝 Neovim
# ============================================
install_neovim() {
    if ! command -v nvim &>/dev/null; then
        info "安裝 Neovim..."
        local arch
        arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
        if [ "$arch" = "amd64" ]; then
            curl -sLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
            sudo tar -C /usr/local --strip-components=1 -xzf nvim-linux-x86_64.tar.gz
            rm -f nvim-linux-x86_64.tar.gz
        else
            sudo apt-get install -y -qq neovim
        fi
        success "Neovim 安裝完成"
    else
        success "Neovim 已存在: $(nvim --version | head -1)"
    fi
}

# ============================================
# 安裝 TPM (Tmux Plugin Manager)
# ============================================
install_tpm() {
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        info "安裝 TPM..."
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        success "TPM 安裝完成 (進入 tmux 後按 prefix + I 安裝插件)"
    else
        success "TPM 已存在"
    fi
}

# ============================================
# 安裝 fzf
# ============================================
install_fzf() {
    if [ ! -d "$HOME/.fzf" ]; then
        info "安裝 fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all --no-bash --no-fish
        success "fzf 安裝完成"
    else
        success "fzf 已存在"
    fi
}

# ============================================
# 建立 Symlinks
# ============================================
create_symlinks() {
    info "建立 symlinks..."

    # zsh
    backup_if_exists "$HOME/.zshrc"
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

    backup_if_exists "$HOME/.bashrc"
    ln -sf "$DOTFILES_DIR/zsh/.bashrc" "$HOME/.bashrc"

    # git
    backup_if_exists "$HOME/.gitconfig"
    ln -sf "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

    # tmux
    backup_if_exists "$HOME/.tmux.conf"
    ln -sf "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

    # starship
    mkdir -p "$HOME/.config"
    backup_if_exists "$HOME/.config/starship.toml"
    ln -sf "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

    # nvim
    backup_if_exists "$HOME/.config/nvim"
    ln -sf "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

    # fzf
    backup_if_exists "$HOME/.fzf.zsh"
    ln -sf "$DOTFILES_DIR/fzf/.fzf.zsh" "$HOME/.fzf.zsh"

    mkdir -p "$HOME/.config/fzf"
    for f in "$DOTFILES_DIR"/fzf/*.sh; do
        [ -f "$f" ] && ln -sf "$f" "$HOME/.config/fzf/$(basename "$f")"
    done

    # scripts
    ln -sf "$DOTFILES_DIR/scripts/tmux-update-city.sh" "$HOME/.tmux-update-city.sh"
    chmod +x "$DOTFILES_DIR/scripts/tmux-update-city.sh"

    success "Symlinks 建立完成"
}

# ============================================
# WSL 專屬設定
# ============================================
setup_wsl() {
    if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
        info "偵測到 WSL，套用 WSL 設定..."

        # .wslconfig (放到 Windows 側)
        local win_home
        win_home=$(wslpath "$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null) || true
        if [ -n "$win_home" ] && [ -d "$win_home" ]; then
            cp "$DOTFILES_DIR/wsl/.wslconfig" "$win_home/.wslconfig"
            success ".wslconfig 已複製到 Windows 家目錄"
        fi

        # SSH server
        sudo systemctl enable ssh 2>/dev/null || true
        sudo systemctl start ssh 2>/dev/null || true

        success "WSL 設定完成"
    fi
}

# ============================================
# 設定 Cloudflared (選擇性)
# ============================================
setup_cloudflared() {
    if [ -f "$DOTFILES_DIR/cloudflared/config.yml" ]; then
        info "Cloudflared 設定檔已包含在 dotfiles 中"
        warn "cloudflared config.yml 包含 tunnel 專屬資訊，需手動調整"
        warn "請執行: cloudflared tunnel login && cloudflared tunnel create <name>"
        warn "然後複製 credentials 並修改 $DOTFILES_DIR/cloudflared/config.yml"
    fi
}

# ============================================
# 設定預設 shell 為 zsh
# ============================================
set_default_shell() {
    if [ "$SHELL" != "$(which zsh)" ]; then
        info "設定預設 shell 為 zsh..."
        chsh -s "$(which zsh)" 2>/dev/null || warn "無法自動切換 shell，請手動執行: chsh -s \$(which zsh)"
        success "預設 shell 已設定為 zsh"
    fi
}

# ============================================
# 主流程
# ============================================
main() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Dotfiles 一鍵部署${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    install_packages
    install_ohmyzsh
    install_fzf
    install_nvm
    install_go
    install_starship
    install_neovim
    install_sesh
    install_tpm
    create_symlinks
    setup_wsl
    setup_cloudflared
    set_default_shell

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  部署完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 重新開啟終端機 或執行: exec zsh"
    echo "  2. 進入 tmux，按 prefix(Ctrl+a) + I 安裝 tmux 插件"
    echo "  3. 開啟 nvim，Lazy 會自動安裝插件"
    if [ -d "$BACKUP_DIR" ]; then
        echo ""
        echo -e "  備份位置: ${YELLOW}$BACKUP_DIR${NC}"
    fi
    echo ""
}

main "$@"
