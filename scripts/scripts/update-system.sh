#!/usr/bin/env bash

# Define color codes
# RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LINUX_DISTRO="unknown"
# Function to set the LINUX_DISTRO variable based on the ID_LIKE or ID value
get_distro() {
  # Attempt to read the ID_LIKE value from /etc/os-release
  ID_LIKE=$(grep ^ID_LIKE= /etc/os-release | cut -d= -f2 | tr -d '"')

  # If ID_LIKE is empty, fall back to reading the ID value
  if [[ -z $ID_LIKE ]]; then
    ID_LIKE=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
  fi

  # Check if ID_LIKE contains "rhel" "fedora" "debian" or "arch"
  if [[ $ID_LIKE == *"rhel"* ]]; then
    LINUX_DISTRO="rhel"
  elif [[ $ID_LIKE == *"fedora"* ]]; then
    LINUX_DISTRO="fedora"
  elif [[ $ID_LIKE == *"debian"* ]]; then
    LINUX_DISTRO="debian"
  elif [[ $ID_LIKE == *"arch"* ]]; then
    LINUX_DISTRO="arch"
  else
    LINUX_DISTRO="unknown"
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
  sudo pacman -S --needed archlinux-keyring
  sudo pacman -Syu
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
  npm-check -g
else
  :
fi

# Check if uv is available in $PATH
if command -v uv &>/dev/null; then
  uv self update
else
  :
fi

echo -e "${GREEN}"
echo -e "System is up to date!${NC}"
echo
