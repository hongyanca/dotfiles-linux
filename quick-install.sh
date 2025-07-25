#!/usr/bin/env bash

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

# Basic packages: git wget curl tar jq unzip bzip2
install_required_dependencies() {
  # Install packages based on the LINUX_DISTRO value
  if [[ $LINUX_DISTRO == "rhel" ]]; then
    echo "Detected RHEL-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    # Install basic packages.
    sudo dnf install -y git wget curl tar jq unzip bzip2 yum-utils open-vm-tools
    sudo dnf config-manager --set-enabled crb
    sudo dnf install epel-release -y
  elif [[ $LINUX_DISTRO == "fedora" ]]; then
    echo "Detected Fedora-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    # Install basic packages.
    sudo dnf install -y git wget curl tar jq unzip bzip2 yum-utils
  elif [[ $LINUX_DISTRO == "debian" ]]; then
    echo "Detected Debian-based distribution. Using apt-get to install packages."
    sudo apt-get update
    sudo apt-get install -y git wget curl tar jq unzip bzip2
  elif [[ $LINUX_DISTRO == "arch" ]]; then
    echo "Detected Arch-based distribution. Using pacman to install packages."
    sudo pacman -S --needed --noconfirm archlinux-keyring
    sudo pacman -Syu
    sudo pacman -S --needed --noconfirm git wget curl tar jq unzip bzip2 util-linux
  else
    echo "Unknown distro" >&2
    exit 1
  fi
}
install_required_dependencies

echo "Clone the Repository..."

rm -rf ~/.dotfiles
git clone --depth=1 --single-branch --branch main https://github.com/hongyanca/dotfiles-linux.git ~/.dotfiles

bash -c "$(curl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/full-experience.sh)"

echo "Setting up symbolic links..."

rm -f ~/.gitignore_global
rm -f ~/.gitconfig
cd ~/.dotfiles || exit
stow git

rm -f ~/.tmux.conf
cd ~/.dotfiles || exit
stow tmux

rm -rf ~/.p10k ~/.p10k.zsh ~/.zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.p10k
cd ~/.dotfiles || exit
stow zsh

mkdir -p ~/.config
rm -rf ~/.config/fish
cd ~/.dotfiles || exit
stow fish

mkdir -p ~/.config
rm -rf ~/.config/mise
cd ~/.dotfiles || exit
stow mise

mkdir -p ~/scripts
cd ~/.dotfiles || exit
function remove_conflicting_scripts() {
  local scripts_dir="$HOME/.dotfiles/scripts/scripts"
  local target_dir="$HOME/scripts"
  local -a script_files

  # Check if source directory exists
  if [ ! -d "$scripts_dir" ]; then
    echo "Error: Source directory not found: $scripts_dir" >&2
    return 1
  fi

  # Check if target directory exists, create if not
  if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to create target directory: $target_dir" >&2
      return 1
    fi
  fi

  # Find all '.sh' files in the scripts directory, extract only the filename
  readarray -t script_files < <(find "$scripts_dir" -maxdepth 1 -type f -name "*.sh" -printf "%f\n")

  # Check if any script found
  if [ ${#script_files[@]} -eq 0 ]; then
    echo "Info: No .sh scripts found under $scripts_dir."
  fi

  # Loop through the file names and remove corresponding files in ~/scripts
  for script_file in "${script_files[@]}"; do
    rm -f "$target_dir/$script_file"
  done
  return 0
}
remove_conflicting_scripts
stow scripts

echo
echo "# Replace Git's 'user.name' and 'user.email' with your own."
echo "git config --global user.name "
echo "git config --global user.email "
echo
echo "# Change default shell to fish"
echo "sudo chsh -s $(which fish) $USER"
echo
echo "# Change default shell to zsh"
echo "sudo chsh -s $(which zsh) $USER"
echo
echo "🌟 Enjoy the new environment! 🌟"
echo
