#!/usr/bin/env bash

# This scripts installs:
#   Dependencies for Neovim plugins
#   Modern cli utilities on Linux distributions
#   Neovim, kickstart.nvim, and LazyVim

LINUX_DISTRO="unknown"
get_distro() {
  # Declare an associative array for distro mappings
  declare -A distro_map
  distro_map["rhel"]="rhel"
  distro_map["almalinux"]="rhel"
  distro_map["fedora"]="fedora"
  distro_map["debian"]="debian"
  distro_map["ubuntu"]="debian"
  distro_map["arch"]="arch"

  # Read ID value
  ID=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')

  # Read the first word of ID_LIKE directly
  ID_LIKE=$(grep ^ID_LIKE= /etc/os-release | cut -d= -f2 | tr -d '"' | awk '{print $1}')

  # Check if the ID exists in our map
  if [[ -n "$ID" ]] && [[ -v distro_map["$ID"] ]]; then
    LINUX_DISTRO="${distro_map[$ID]}"
  else
    # If ID is not in the map, check ID_LIKE
    if [[ -n "$ID_LIKE" ]] && [[ -v distro_map["$ID_LIKE"] ]]; then
      LINUX_DISTRO="${distro_map[$ID_LIKE]}"
    fi
    # If no match found, keep unknown
  fi
}
get_distro

# Basic packages: wget curl zsh fish stow tar jq unzip bzip2 make git xclip
install_required_dependencies() {
  # Install packages based on the LINUX_DISTRO value
  if [[ $LINUX_DISTRO == "rhel" ]]; then
    echo "Detected RHEL-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    # Must manually instal GNU stow, xclip, zsh-syntax-highlighting on RHEL-based distributions
    cd /tmp || exit 1
    wget https://rpmfind.net/linux/fedora/linux/releases/43/Everything/x86_64/os/Packages/s/stow-2.4.1-3.fc43.noarch.rpm
    sudo yum localinstall -y stow-2.4.1-3.fc43.noarch.rpm
    wget https://rpmfind.net/linux/opensuse/distribution/leap/15.6/repo/oss/x86_64/xclip-0.13-150400.9.3.1.x86_64.rpm
    wget https://rpmfind.net/linux/fedora/linux/releases/43/Everything/x86_64/os/Packages/z/zsh-syntax-highlighting-0.8.0-6.fc43.noarch.rpm
    sudo yum localinstall -y xclip-0.13-150400.9.3.1.x86_64.rpm zsh-syntax-highlighting-0.8.0-6.fc43.noarch.rpm
    # Install basic packages.
    sudo dnf install -y wget curl zsh fish tar jq unzip bzip2 make git sqlite-devel \
      yum-utils gcc make python3-pip p7zip util-linux-user bat btop gdu gpg \
      zlib-devel openssl-devel readline-devel libffi-devel xz-devel bzip2-devel
    python3 -m pip install --upgrade pip
    python3 -m pip install --user --upgrade pynvim
  elif [[ $LINUX_DISTRO == "fedora" ]]; then
    echo "Detected Fedora-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    # Install basic packages.
    sudo dnf install -y wget curl zsh fish stow tar jq unzip bzip2 make git xclip \
      yum-utils gcc make python3-pip p7zip util-linux-user zsh-syntax-highlighting \
      zlib-devel openssl-devel readline-devel libffi-devel xz-devel bzip2-devel \
      sqlite-devel bat btop gdu gpg
    python3 -m pip install --upgrade pip
    python3 -m pip install --user --upgrade pynvim
  elif [[ $LINUX_DISTRO == "debian" ]]; then
    echo "Detected Debian-based distribution. Using apt-get to install packages."
    sudo apt-get update
    sudo apt-get install -y wget curl zsh fish stow tar jq unzip bzip2 make git xclip \
      gcc make libbz2-dev python3-pip p7zip passwd zsh-syntax-highlighting \
      build-essential libssl-dev zlib1g-dev libreadline-dev libsqlite3-dev \
      bat btop gdu gpg
    # bat will be installed as batcat
    sudo rm -f /usr/local/bin/bat
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
    python3 -m pip install --upgrade pip --break-system-packages
    python3 -m pip install --user --upgrade pynvim --break-system-packages
  elif [[ $LINUX_DISTRO == "arch" ]]; then
    echo "Detected Arch-based distribution. Using pacman to install packages."
    sudo pacman -S --needed --noconfirm archlinux-keyring
    sudo pacman -Syu
    sudo pacman -S --needed --noconfirm wget curl zsh fish stow tar jq git xclip \
      gcc make python python-pip p7zip unzip util-linux zsh-syntax-highlighting \
      openssl python-pyopenssl zlib readline libffi xz bzip2 sqlite \
      bat btop gdu gpg
    sudo rm -f /usr/share/zsh-syntax-highlighting
    sudo ln -s /usr/share/zsh/plugins/zsh-syntax-highlighting /usr/share/zsh-syntax-highlighting
    python3 -m pip install --upgrade pip --break-system-packages
    python3 -m pip install --user --upgrade pynvim --break-system-packages
  else
    echo "Unknown distro" >&2
    exit 1
  fi
}
install_required_dependencies

# Install mise. https://mise.jdx.dev/getting-started.html
curl https://mise.run | sh
eval "$(~/.local/bin/mise activate bash)"
mise i uv
# Install Node.js via mise and set up npm global packages directory
rm -f "$HOME/.npmrc"
mkdir "$HOME/.npm-packages"
mise use --global node@24
eval "$(~/.local/bin/mise activate bash)"
npm config set prefix "$HOME/.npm-packages"
npm install -g tree-sitter-cli neovim pyright npm-check npm

# Install modern utilities
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/install-modern-utils.sh)"

# Install neovim, kickstart.nvim
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/install-neovim.sh)"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/kickstart-nvim-install.sh)"

sudo bash -c "cat <<'EOF' >> /root/.bashrc

force_color_prompt=yes
color_prompt=yes

if command -v nvim &>/dev/null; then
    alias vi='nvim'
    alias vim='nvim'
    export EDITOR='nvim'
    export VISUAL='nvim'
fi

if [[ \$EUID -eq 0 ]]; then
    PS1='\\u@\\h:\\w # '
else
    PS1='\\u@\\h:\\w \$ '
fi

EOF"
