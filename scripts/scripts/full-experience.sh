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
    # Install basic packages.
    sudo dnf install -y wget curl zsh fish stow tar jq unzip bzip2 make git xclip \
      yum-utils gcc make python3-pip p7zip util-linux-user zsh-syntax-highlighting \
      bat btop gdu
    python3 -m pip install --upgrade pip
    python3 -m pip install --user --upgrade pynvim
    # Install Node.js 22.x
    # Use `sudo dnf module list nodejs` to list available Node.js versions
    # Use `sudo dnf module reset nodejs:20/common` to reset the default version
    sudo dnf module install nodejs:22/common
  elif [[ $LINUX_DISTRO == "fedora" ]]; then
    echo "Detected Fedora-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    # Install basic packages.
    sudo dnf install -y wget curl zsh fish stow tar jq unzip bzip2 make git xclip \
      yum-utils gcc make python3-pip p7zip util-linux-user zsh-syntax-highlighting \
      bat btop gdu nodejs npm
    python3 -m pip install --upgrade pip
    python3 -m pip install --user --upgrade pynvim
  elif [[ $LINUX_DISTRO == "debian" ]]; then
    echo "Detected Debian-based distribution. Using apt-get to install packages."
    sudo apt-get update
    sudo apt-get install -y wget curl zsh fish stow tar jq unzip bzip2 make git xclip \
      gcc make libbz2-dev python3-pip p7zip passwd zsh-syntax-highlighting \
      bat btop gdu
    python3 -m pip install --upgrade pip --break-system-packages
    python3 -m pip install --user --upgrade pynvim --break-system-packages
    # Install Node.js 22.x
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs
  elif [[ $LINUX_DISTRO == "arch" ]]; then
    echo "Detected Arch-based distribution. Using pacman to install packages."
    sudo pacman -S --needed --noconfirm archlinux-keyring
    sudo pacman -Syu
    sudo pacman -S --needed --noconfirm wget curl zsh fish stow tar jq unzip bzip2 make git xclip \
      gcc make python python-pip p7zip util-linux zsh-syntax-highlighting \
      bat btop gdu nodejs npm
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

install_npm_packages() {
  # Install npm packages globally without sudo
  mkdir -p "$HOME/.npm-packages"
  npm config set prefix "$HOME/.npm-packages"
  export NPM_PACKAGES="$HOME/.npm-packages"
  export PATH="$PATH:$NPM_PACKAGES/bin"
  USER_GRP="$(id -un):$(id -gn)"
  sudo mkdir -p /usr/local/n
  sudo chown -R "$USER_GRP" "/usr/local/n"
  sudo chown -R "$USER_GRP" "/usr/local/lib"
  sudo chown -R "$USER_GRP" "/usr/local/bin"
  sudo chown -R "$USER_GRP" "/usr/local/include"
  sudo chown -R "$USER_GRP" "/usr/local/share"
  sudo chown -R "$USER_GRP" "/usr/local/share/man/"
  echo "Installing Node.js global packages..."
  npm cache clean --force
  rm -rf "$HOME/.npm-packages/lib/node_modules/tree-sitter-cli"
  rm -rf "$HOME/.npm-packages/lib/node_modules/neovim"
  rm -rf "$HOME/.npm-packages/lib/node_modules/pyright"
  rm -rf "$HOME/.npm-packages/lib/node_modules/n"
  rm -rf "$HOME/.npm-packages/lib/node_modules/npm-check"
  npm install tree-sitter-cli neovim pyright n npm-check -g
}
install_npm_packages

# Install modern utilities
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/install-modern-utils.sh)"

# Install neovim, kickstart.nvim, and LazyVim
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/install-neovim.sh)"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/kickstart-nvim-install.sh)"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/lazyvim-install.sh)"
