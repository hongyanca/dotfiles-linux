#!/usr/bin/env bash

# Define color codes
# RED='\033[0;31m'
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
  distro_map["cachyos"]="arch"

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

# Update installed packages based on the LINUX_DISTRO value
if [[ $LINUX_DISTRO == "rhel" ]]; then
  sudo dnf upgrade --refresh -y
  # sudo dnf autoremove
  # sudo dnf clean all
elif [[ $LINUX_DISTRO == "fedora" ]]; then
  sudo dnf upgrade --refresh -y
  # sudo dnf autoremove
  # sudo dnf clean all
elif [[ $LINUX_DISTRO == "debian" ]]; then
  sudo apt-get update
  sudo NEEDRESTART_MODE=a apt-get -o APT::Get::Always-Include-Phased-Updates=true upgrade -y
  sudo apt-get autoremove -y
elif [[ $LINUX_DISTRO == "arch" ]]; then
  sudo pacman -S --needed --noconfirm archlinux-keyring
  sudo pacman -Syyu
  yay -Syyu --noconfirm
  sudo needrestart -r a
  # sudo pacman -Sc
  echo
  echo -e "After kernel update, reboot and re-generate initramfs: ${BLUE}"
  echo -e "sudo mkinitcpio -P ${NC}"
  echo
else
  echo "Unknown distro" >&2
  exit 1
fi

# Check if npm-check is available in $PATH
if command -v npm-check &>/dev/null; then
  npm-check --global --update-all
else
  :
fi

# Check if uv is available in $PATH
if command -v uv >/dev/null 2>&1; then
  UV_PATH=$(which uv)
  if echo "$UV_PATH" | grep -q "mise"; then
    # Use mise to update uv and tools
    :
  else
    uv self update && uv tool upgrade --all
  fi
else
  :
fi

# Update mise and tools
if command -v mise >/dev/null 2>&1; then
  mise self-update -y
  mise up -y
  mise prune -y
else
  :
fi

echo -e "${GREEN}"
echo -e "System is up to date!${NC}"
echo
