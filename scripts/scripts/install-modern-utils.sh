#!/usr/bin/env bash

# This script automates the process of downloading, extracting, and installing
# the latest release of modern Linux utilities from GitHub.

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_post_install_info() {
  echo ""
  echo "Examples of shell rc files to integrate these modern utilities:"
  echo -e "${BLUE}https://github.com/hongyanca/dotfiles-linux${NC}"
  echo ""
}

LINUX_DISTRO="unknown"
# Function to set the LINUX_DISTRO variable based on the ID_LIKE or ID value
get_distro() {
  # Attempt to read the ID_LIKE value from /etc/os-release
  ID_LIKE=$(grep ^ID_LIKE= /etc/os-release | cut -d= -f2 | tr -d '"')

  # If ID_LIKE is empty, fall back to reading the ID value
  if [[ -z $ID_LIKE ]]; then
    ID_LIKE=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
  fi

  # Check if ID_LIKE contains "rhel" or "debian"
  if [[ $ID_LIKE == *"rhel"* ]]; then
    LINUX_DISTRO="rhel"
  elif [[ $ID_LIKE == *"debian"* ]]; then
    LINUX_DISTRO="debian"
  elif [[ $ID_LIKE == *"arch"* ]]; then
    LINUX_DISTRO="arch"
  else
    LINUX_DISTRO="unknown"
  fi
}
get_distro


install_npm_packages() {
# Install npm packages globally without sudo
mkdir -p "$HOME/.npm-packages"
npm config set prefix "$HOME/.npm-packages"
export NPM_PACKAGES="$HOME/.npm-packages"
export PATH="$PATH:$NPM_PACKAGES/bin"
USER_GRP="$(id -un):$(id -gn)"
sudo mkdir -p /usr/local/n
sudo chown -R $USER_GRP /usr/local/n
sudo chown -R $USER_GRP /usr/local/lib
sudo chown -R $USER_GRP /usr/local/bin
sudo chown -R $USER_GRP /usr/local/include
sudo chown -R $USER_GRP /usr/local/share
sudo chown -R $USER_GRP /usr/local/share/man/
echo "Installing Node.js global packages..."
npm install tree-sitter-cli neovim pyright n npm-check -g
}


REQUIRED_PKGS=("wget" "curl" "zsh" "fish" "stow" "tar" "jq" "unzip" "bzip2" "make" "git" "xclip")
REQ_PKGS_STR="${REQUIRED_PKGS[*]}"


# Install packages based on the LINUX_DISTRO value
if [[ $LINUX_DISTRO == "rhel" ]]; then
  echo "Detected RHEL-based distribution. Using dnf to install $package."
  sudo dnf upgrade --refresh -y
  sudo dnf install -y yum-utils gcc make python3-pip p7zip util-linux-user zsh-syntax-highlighting
  python3 -m pip install --upgrade pip
  python3 -m pip install --user --upgrade pynvim
  # Install Node.js 22.x
  # Use `sudo dnf module list nodejs` to list available Node.js versions
  # Use `sudo dnf module reset nodejs:20/common` to reset the default version
  sudo dnf module install nodejs:22/common
  install_npm_packages
elif [[ $LINUX_DISTRO == "debian" ]]; then
  echo "Detected Debian-based distribution. Using apt-get to install $package."
  sudo apt-get update
  sudo apt-get install -y gcc make libbz2-dev python3-pip p7zip passwd zsh-syntax-highlighting
  python3 -m pip install --upgrade pip --break-system-packages
  python3 -m pip install --user --upgrade pynvim --break-system-packages
  # Install Node.js 22.x
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs
  install_npm_packages
elif [[ $LINUX_DISTRO == "arch" ]]; then
  echo "Detected Arch-based distribution. Using pacman to install $package."
  sudo pacman -S --needed --noconfirm archlinux-keyring
  sudo pacman -Syu
  sudo pacman -S --needed --noconfirm gcc make python python-pip lua nodejs npm p7zip util-linux zsh-syntax-highlighting
  sudo rm -f /usr/share/zsh-syntax-highlighting
  sudo ln -s /usr/share/zsh/plugins/zsh-syntax-highlighting /usr/share/zsh-syntax-highlighting
  python3 -m pip install --upgrade pip --break-system-packages
  python3 -m pip install --user --upgrade pynvim --break-system-packages
  install_npm_packages
  sudo pacman -S --needed --noconfirm $REQ_PKGS_STR
  # Arch Linux is a rolling distro, so it already provides the latest packages
  # Don't need to install binary releases for GitHub
  sudo pacman -S --needed --noconfirm btop fzf fd bat git-delta lazygit lsd ripgrep gdu zoxide fastfetch yazi
  print_post_install_info
  exit 0
else
  echo "Unknown distro" >&2
  exit 1
fi


# Function to install a required package based on the distribution
install_required_package() {
  package=$1

  # Function to check if a package is installed
  is_installed() {
    if command -v "$package" &>/dev/null; then
      return 0
    else
      return 1
    fi
  }

  # Check if the package is already installed
  if is_installed; then
    echo -e "${GREEN}✔ ${BLUE}$package${NC}"
    return 0
  fi

  # Check if LINUX_DISTRO contains 'rhel' or 'debian' and install the package
  if [[ $LINUX_DISTRO == "rhel" ]]; then
    sudo dnf install -y "$package"
  elif [[ $LINUX_DISTRO == "debian" ]]; then
    sudo apt-get install -y "$package"
  elif [[ $LINUX_DISTRO == "arch" ]]; then
    :
  else
    echo "Unsupported distribution."
    return 1
  fi
}


echo "Installing required packages..."
# Install each package in the packages array
for package in "${REQUIRED_PKGS[@]}"; do
  install_required_package "$package"
done


# Function to install the latest release of a GitHub repository
# Usage: install_latest_release "repo" "cmd_local_ver" "asset_suffix" ["alt_util_name"] ["symlink_name"]
# Parameters:
# - repo: The GitHub repository in the format "owner/repo" (e.g., "junegunn/fzf").
# - cmd_local_ver: The string that fetches the installed version of the utility.
# - asset_suffix: The suffix of the asset file to download (e.g., "linux_amd64.tar.gz").
# - alt_util_name (optional): An alternative name for the utility to use during installation.
# - symlink_name (optional): A name for creating a symbolic link to the installed utility.
# Example: install_latest_release "junegunn/fzf" "linux_amd64.tar.gz"
# Example: install_latest_release "BurntSushi/ripgrep" "x86_64-unknown-linux-musl.tar.gz" "rg"
# Example: install_latest_release "dundee/gdu" "linux_amd64_static.tgz" "gdu_linux_amd64_static" "gdu"
install_latest_release_from_gh() {
  local repo=$1 cmd_local_ver=$2 asset_suffix=$3 alt_util_name=$4 symlink_name=$5
  local installed_ver latest_ver latest_release asset_filename asset_url decomp_dir
  local util_bin_fn util_name util_path

  installed_ver=$(eval "$cmd_local_ver" 2>/dev/null)
  latest_ver=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')
  # Remove 'v' prefix from latest_ver if it exists
  if [[ $latest_ver == v* ]]; then
    latest_ver=${latest_ver#v}
  fi
  # Compare versions
  if [ "$installed_ver" == "$latest_ver" ]; then
    echo -e "${GREEN}✔ ${BLUE}$repo is already up to date.${NC}"
    return 1
  else
    echo
    echo "Installing $repo v$latest_ver..."
  fi

  util_name=$(echo "$repo" | awk -F'/' '{print $2}')
  latest_release=$(curl -s "https://api.github.com/repos/$repo/releases/latest")
  asset_filename=$(echo "$latest_release" | jq -r --arg suffix "$asset_suffix" '.assets[] | select(.name | endswith($suffix)) | .name')
  asset_url=$(echo "$latest_release" | jq -r --arg suffix "$asset_suffix" '.assets[] | select(.name | endswith($suffix)) | .browser_download_url')

  echo "Downloading $util_name from $asset_url"
  wget -q --show-progress -O "$asset_filename" "$asset_url"

  decomp_dir="tmp-$util_name-install"
  echo "Extracting $asset_filename to $decomp_dir"
  rm -rf "$decomp_dir"
  mkdir -p "$decomp_dir"

  if [[ "$asset_filename" == *.zip ]]; then
    unzip "$asset_filename" -d "$decomp_dir"
  else
    tar -xf "$asset_filename" -C "$decomp_dir"
  fi

  # Use the provided alternative utility name if given
  if [ -n "$alt_util_name" ]; then
    util_bin_fn=$alt_util_name
  else
    util_bin_fn=$util_name
  fi
  # Find the executable file
  util_path=$(find "$decomp_dir" -type f -name "$util_bin_fn" -executable 2>/dev/null)
  sudo install "$util_path" /usr/local/bin

  # Extract the last part of the path if util_bin_fn contains /
  util_bin_fn=$(basename "$util_bin_fn")

  # Check if the utility has been installed
  if [ -f "/usr/local/bin/$util_bin_fn" ]; then
    # Get the file creation time in seconds since epoch
    file_creation_time=$(stat -c %Y "/usr/local/bin/$util_bin_fn")
    current_time=$(date +%s)
    time_diff=$((current_time - file_creation_time))

    # Check if the file was created within the last minute (60 seconds)
    if [ $time_diff -le 60 ]; then
      echo -e "${GREEN}✔ ${BLUE}$util_name${NC} has been installed successfully."
    else
      echo "$util_name has already been installed previously."
    fi
  else
    echo -e "${RED}Failed to install $util_name.${NC}"
  fi

  # Create a symbolic link if the fourth argument is provided
  if [ -n "$symlink_name" ]; then
    sudo ln -sf "/usr/local/bin/$util_bin_fn" "/usr/local/bin/$symlink_name"
    ls -lh "/usr/local/bin/$symlink_name"
  fi
  ls -lh "/usr/local/bin/$util_bin_fn"
  "/usr/local/bin/$util_bin_fn" --version

  printf "Cleaning up...\n\n"
  rm -rf "$asset_filename" "$decomp_dir"
  return 0
}


install_latest_release_from_gh "aristocratos/btop" \
  "btop --version | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-linux-musl.tbz"
install_latest_release_from_gh "junegunn/fzf" \
  "fzf --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "linux_amd64.tar.gz"
install_latest_release_from_gh "sharkdp/fd" \
  "fd --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-gnu.tar.gz"
install_latest_release_from_gh "sharkdp/bat" \
  "bat --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-gnu.tar.gz"
install_latest_release_from_gh "jesseduffield/lazygit" \
  "lazygit --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1" \
  "Linux_x86_64.tar.gz"
install_latest_release_from_gh "dandavison/delta" \
  "delta --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-gnu.tar.gz"
install_latest_release_from_gh "lsd-rs/lsd" \
  "lsd --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-gnu.tar.gz"
install_latest_release_from_gh "BurntSushi/ripgrep" \
  "rg --version | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-musl.tar.gz" "rg"
install_latest_release_from_gh "dundee/gdu" \
  "gdu --version | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "linux_amd64_static.tgz" "gdu_linux_amd64_static" "gdu"
install_latest_release_from_gh "ajeetdsouza/zoxide" \
  "zoxide --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-musl.tar.gz"
install_latest_release_from_gh "fastfetch-cli/fastfetch" \
  "fastfetch --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "linux-amd64.tar.gz"
install_latest_release_from_gh "sxyazi/yazi" \
  "yazi --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-musl.zip"
# Install yazi cli tool ya for plugin/flavor management
install_latest_release_from_gh "sxyazi/yazi" \
  "ya --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
  "x86_64-unknown-linux-musl.zip" "ya"

print_post_install_info
