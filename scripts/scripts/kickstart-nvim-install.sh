#!/usr/bin/env bash

printf "Downloading kickstart.nvim to \e[34m~/.config/nvim\e[0m\n"

rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.cache/nvim
rm -rf ~/.config/nvim
git clone --depth 1 https://github.com/hongyanca/kickstart.nvim.git ~/.config/nvim

# Check if nvim binary is available
if ! command -v nvim &> /dev/null
then
  # Print blue text if nvim is not found
  printf "Neovim not found. Use this script to install neovim:"
  printf "\e[34mcurl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/install-neovim.sh\e[0m\n"
else
  # Run nvim in headless mode and quit if nvim is found
  NVIM_APPNAME=nvim nvim --headless -c 'quitall'
  printf "\n\e[34mDon't panic if there are installtion errors.\e[0m\n\n"
fi
