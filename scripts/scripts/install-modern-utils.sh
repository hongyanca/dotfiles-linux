#!/usr/bin/env bash

# This script automates the process of downloading, extracting, and installing
# the latest release of modern Linux utilities from GitHub.

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# KV Map of Linux Distributions and their packages
declare -A DISTRO_PACKAGES
DISTRO_PACKAGES["rhel"]="bat btop gdu fzf ripgrep"
DISTRO_PACKAGES["fedora"]="bat btop gdu git-delta fzf ripgrep zoxide lsd"
DISTRO_PACKAGES["arch"]="bat btop gdu git-delta fzf ripgrep zoxide lsd fd lazygit fastfetch"
DISTRO_PACKAGES["debian"]="bat btop gdu"

# Function to install packages based on distribution
install_packages() {
  local packages_list_str=("${DISTRO_PACKAGES[$LINUX_DISTRO]}")
  # Ignore the lsp warnings, this is the corret way to convert a string to an array
  read -ra packages <<<"$packages_list_str"

  case "$LINUX_DISTRO" in
  "rhel" | "fedora")
    sudo dnf upgrade --refresh -y
    sudo dnf install -y "${packages[@]}"
    ;;
  "arch")
    sudo pacman -S --needed --noconfirm archlinux-keyring
    sudo pacman -Syu
    sudo pacman -S --needed --noconfirm "${packages[@]}"
    ;;
  "debian")
    sudo apt-get update -y
    sudo apt-get install -y "${packages[@]}"
    sudo rm -f /usr/local/bin/bat
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
    ;;
  *)
    echo "Error: Unsupported Linux distribution."
    return 1
    ;;
  esac

  return 0
}

# Call the install function if distro is defined
if [[ -n "$LINUX_DISTRO" ]]; then
  install_packages "$LINUX_DISTRO"
else
  echo "Error: Unsupported Linux distribution."
  exit 1
fi

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
    # api.github.com has a rate limit
    sleep 3
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
  cd /tmp || exit 1
  wget -q -O "$asset_filename" "$asset_url"

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

  # Create a symbolic link if the fifth argument is provided
  if [ -n "$symlink_name" ]; then
    sudo ln -sf "/usr/local/bin/$util_bin_fn" "/usr/local/bin/$symlink_name"
    ls -lh "/usr/local/bin/$symlink_name"
  fi
  ls -lh "/usr/local/bin/$util_bin_fn"
  "/usr/local/bin/$util_bin_fn" --version

  printf "Cleaning up...\n"
  rm -rf "$asset_filename" "$decomp_dir"
  return 0
}

function install_git-delta() {
  install_latest_release_from_gh "dandavison/delta" \
    "delta --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "x86_64-unknown-linux-gnu.tar.gz"
}
function install_fzf() {
  install_latest_release_from_gh "junegunn/fzf" \
    "fzf --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "linux_amd64.tar.gz"
}
function install_fd() {
  install_latest_release_from_gh "sharkdp/fd" \
    "fd --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "x86_64-unknown-linux-gnu.tar.gz"
}
function install_lazygit() {
  install_latest_release_from_gh "jesseduffield/lazygit" \
    "lazygit --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1" \
    "Linux_x86_64.tar.gz"
}
function install_lsd() {
  install_latest_release_from_gh "lsd-rs/lsd" \
    "lsd --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "x86_64-unknown-linux-gnu.tar.gz"
}
function install_ripgrep() {
  install_latest_release_from_gh "BurntSushi/ripgrep" \
    "rg --version | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "x86_64-unknown-linux-musl.tar.gz" "rg"
}
function install_zoxide() {
  install_latest_release_from_gh "ajeetdsouza/zoxide" \
    "zoxide --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "x86_64-unknown-linux-musl.tar.gz"
}
function install_fastfetch() {
  install_latest_release_from_gh "fastfetch-cli/fastfetch" \
    "fastfetch --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'" \
    "linux-amd64.tar.gz"
}

case "$LINUX_DISTRO" in
"rhel")
  install_git-delta
  install_lsd
  install_zoxide
  install_fd
  install_lazygit
  install_fastfetch
  ;;
"fedora")
  install_fd
  install_lazygit
  install_fastfetch
  ;;
"arch")
  :
  ;;
"debian")
  install_git-delta
  install_fzf
  install_lsd
  install_ripgrep
  install_zoxide
  install_fd
  install_lazygit
  install_fastfetch
  ;;
*)
  echo "Error: Unsupported Linux distribution."
  return 1
  ;;
esac

print_post_install_info() {
  echo
  echo "If you see error like:"
  echo -e "${RED}jq: error (at <stdin>:1): Cannot iterate over null (null)${NC}"
  echo "You have reached the GitHub API rate limit."
  echo "Please wait for a while and try again."
  echo
  echo "Examples of shell rc files to integrate these modern utilities:"
  echo -e "${BLUE}https://github.com/hongyanca/dotfiles-linux${NC}"
  echo
}

print_post_install_info
