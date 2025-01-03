#!/usr/bin/env bash

printf "Downloading kickstart.nvim to \e[34m~/.config/nvim\e[0m\n"

rm -rf ~/.local/share/nvim-lazyvim
rm -rf ~/.local/state/nvim-lazyvim
rm -rf ~/.cache/nvim-lazyvim
rm -rf ~/.config/nvim-lazyvim
git clone --depth 1 https://github.com/hongyanca/lazyvim_config ~/.config/nvim-lazyvim

# Check if nvim binary is available
if ! command -v nvim &> /dev/null
then
  # Print blue text if nvim is not found
  printf "Neovim not found. Use this script to install neovim:"
  printf "\e[34mcurl -fsSL https://raw.githubusercontent.com/hongyanca/dotfiles-linux/refs/heads/main/scripts/scripts/install-neovim.sh\e[0m\n"
else
  # Run nvim in headless mode and quit if nvim is found
  nvim --headless -c 'quitall'
  printf "\e[34mDon't panic if there are installtion errors.\e[0m\n"
fi

print_post_install_info() {
  echo "For fish, add the following line to ~/.config/fish/config.fish"
  echo "set -x NVIM_APPNAME nvim-lazyvim"
  echo
  echo "For bash or zsh, add the following line to ~/.bashrc or ~/.zshrc"
  echo "alias nvim='NVIM_APPNAME=nvim-lazyvim nvim'"
  echo
  echo "More examples of shell rc files to integrate NVIM_APPNAME:"
  printf "\e[34mhttps://github.com/hongyanca/dotfiles-linux\e[0m\n"
}
print_post_install_info
