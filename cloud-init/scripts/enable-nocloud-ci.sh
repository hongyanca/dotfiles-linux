#!/usr/bin/env bash

sudo mkdir -p /usr/local/bin
sudo cp -f ~/.dotfiles/cloud-init/scripts/update-issue.sh /usr/local/bin/update-issue.sh

###################################################################################################
# Nocloud cloud-init configuration
sudo mkdir -p /etc/cloud/cloud.cfg.d/
cat <<EOF >/tmp/99-fake_cloud.cfg
# Configure cloud-init for NoCloud
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: system-boot
EOF
sudo cp -f /tmp/99-fake_cloud.cfg /etc/cloud/cloud.cfg.d/99-fake_cloud.cfg
sudo rm -f /tmp/99-fake_cloud.cfg

cat <<EOF >/tmp/99-disable-network-config.cfg
network: {config: disabled}
EOF
sudo cp -f /tmp/99-disable-network-config.cfg /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo rm -f /tmp/99-disable-network-config.cfg

###################################################################################################
# Install cloud-init and copy config file based on Linux distro
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

# Copy cloud-init config file
install_required_dependencies() {
  # Install packages based on the LINUX_DISTRO value
  if [[ $LINUX_DISTRO == "rhel" ]]; then
    echo "Detected RHEL-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    sudo dnf install -y cloud-init
    sudo cp -f ~/.dotfiles/cloud-init/rhel/cloud.cfg /etc/cloud/cloud.cfg
  elif [[ $LINUX_DISTRO == "fedora" ]]; then
    echo "Detected Fedora-based distribution. Using dnf to install packages."
    sudo dnf upgrade --refresh -y
    sudo dnf install -y cloud-init
    # Must manually config cloud-init for Fedora Linux
    # sudo cp -f ~/.dotfiles/cloud-init/rhel/cloud.cfg /etc/cloud/cloud.cfg
  elif [[ $LINUX_DISTRO == "debian" ]]; then
    echo "Detected Debian-based distribution. Using apt-get to install packages."
    sudo apt-get update
    sudo apt-get install -y cloud-init
    sudo cp -f ~/.dotfiles/cloud-init/ubuntu/cloud.cfg /etc/cloud/cloud.cfg
  elif [[ $LINUX_DISTRO == "arch" ]]; then
    echo "Detected Arch-based distribution. Using pacman to install packages."
    sudo pacman -S --needed --noconfirm archlinux-keyring
    sudo pacman -Syu
    sudo pacman -S --needed --noconfirm cloud-init
    # Must manually config cloud-init for Arch Linux
  else
    echo "Unknown distro" >&2
    exit 1
  fi
}
install_required_dependencies
