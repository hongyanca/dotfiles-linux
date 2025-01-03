#!/usr/bin/env bash

# Define color codes
# RED='\033[0;31m'
# GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

sudo pacman -S --needed archlinux-keyring
yay -Syu

echo ""
echo -e "To remove packages that are no longer installed: ${BLUE}"
echo -e "sudo pacman -Sc"
echo -e "${NC}"
echo -e "After kernel update, re-generate initramfs: ${BLUE}"
echo -e "sudo mkinitcpio -P"
echo -e "${NC}"

echo "Check npm global packages"
npm-check -g

echo ""
python3 -m pip install --user --upgrade pynvim --break-system-packages

echo ""
