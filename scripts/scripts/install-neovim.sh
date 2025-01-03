#!/usr/bin/env bash

# Get the CPU architecture
ARCH=$(uname -m)

# Check if the architecture is aarch64
if [ "$ARCH" != "x86_64" ]; then
  echo "Warning: This script is designed for x86_64 architecture, but the current architecture is $ARCH."
  exit 1
fi

# GitHub API URL for Neovim releases
GITHUB_API_URL="https://api.github.com/repos/neovim/neovim/releases"

# Detect OS
OS=$(uname -s)

# Set variables based on OS
case "$OS" in
Darwin)
  INSTALL_DIR="$HOME/Applications/nvim-macos-x86_64"
  PACKAGE_NAME="nvim-macos-x86_64.tar.gz"
  ;;
Linux)
  INSTALL_DIR="$HOME/.local/nvim-linux64"
  PACKAGE_NAME="nvim-linux64.tar.gz"
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

# Temporary file path for the downloaded package
PACKAGE_PATH="/tmp/$PACKAGE_NAME"

# Function to install a given version
install_version() {
  local version_type="$1"
  local download_url
  local version

  if [ "$version_type" = "nightly" ] || [ "$version_type" = "prerelease" ]; then
    # Fetch the JSON response using curl
    response=$(curl -s "$GITHUB_API_URL")

    # Extract the 'body' field of the latest prerelease and filter out the version string
    version=$(echo "$response" | jq -r '.[] | select(.prerelease) | .body' | grep -Eo 'NVIM\s+\S+')
    download_url=$(echo "$response" | jq -r ".[] | select(.prerelease) | .assets[] | select(.name == \"$PACKAGE_NAME\") | .browser_download_url" | head -n 1)
  elif [ "$version_type" = "latest" ]; then
    response=$(curl -s "$GITHUB_API_URL/latest")
    version=$(echo "$response" | jq -r '.tag_name')
    download_url=$(echo "$response" | jq -r ".assets[] | select(.name == \"$PACKAGE_NAME\") | .browser_download_url")
  else
    echo "Invalid version type: $version_type"
    return 1
  fi

  if [ -z "$version" ] || [ -z "$download_url" ]; then
    echo "Could not determine download URL or version for $version_type"
    return 1
  fi

  # Get installed Neovim version
  if [ -x "$INSTALL_DIR"/bin/nvim ]; then
    installed_version=$(NVIM_APPNAME=nvim-dev "$INSTALL_DIR"/bin/nvim --version | head -n 1 | grep -Eo 'NVIM\s+\S+')
  else
    installed_version=""
  fi

  echo "The latest Neovim $version_type version is: $version"
  echo "Installed Neovim version is:  $installed_version"

  # Compare installed version with the latest prerelease version
  if [ "$version" != "$installed_version" ]; then
    echo "The installed version is outdated. Downloading the latest $version_type version..."

    if [ -n "$download_url" ]; then
      echo "Downloading from $download_url..."

      # Download the tarball to /tmp/$PACKAGE_NAME
      curl -L -o "$PACKAGE_PATH" "$download_url"

      # Extract the tarball to the installation directory
      echo "Extracting Neovim to $INSTALL_DIR..."
      rm -rf "$INSTALL_DIR"
      if [ "$OS" = "Darwin" ]; then
        xattr -c "$PACKAGE_PATH"
      fi
      if [ "$OS" = "Darwin" ]; then
        tar -xzf "$PACKAGE_PATH" -C "$HOME/Applications/"
      elif [ "$OS" = "Linux" ]; then
        tar -xzf "$PACKAGE_PATH" -C "$HOME/.local/"
      fi

      # Clean up
      rm -rf "$PACKAGE_PATH"
      echo "Neovim updated successfully."

      # Post-Installation Script
      post_install_actions "$version"
    else
      echo "Could not find the download URL for $PACKAGE_NAME."
    fi
  else
    echo "The installed version is up-to-date."
  fi
}

# Function for post-installation actions
post_install_actions() {
  local installed_version="$1"
  # Print out green text "neovim VERSION_NUMBER has been installed to "$INSTALL_DIR"/bin/nvim
  if [ -x "$INSTALL_DIR"/bin/nvim ]; then
    printf "\e[32mNeovim %s has been installed to %s/bin/nvim\e[0m\n" "$installed_version" "$INSTALL_DIR"
  fi

  # Check if /usr/bin/nvim is a symlink
  if [ -L "/usr/bin/nvim" ]; then
    # Delete the existing symlink
    echo "Removing existing symlink /usr/bin/nvim"
    sudo rm "/usr/bin/nvim"
  fi

  # Create a new symlink
  if [ ! -L "/usr/bin/nvim" ]; then
    echo "Creating symlink /usr/bin/nvim to $INSTALL_DIR/bin/nvim"
    sudo ln -s "$INSTALL_DIR/bin/nvim" "/usr/bin/nvim"
  fi
}

# Check for command line argument
if [ -n "$1" ]; then
  case "$1" in
  "nightly" | "prerelease")
    install_version "$1"
    ;;
  "latest")
    install_version "latest"
    ;;
  *)
    echo "Invalid argument: $1. Use 'nightly', 'prerelease' or 'latest' or leave empty for latest release."
    exit 1
    ;;
  esac
else
  install_version "latest"
fi
