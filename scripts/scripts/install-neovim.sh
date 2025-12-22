#!/usr/bin/env bash

set -euo pipefail

#######################################
# Constants
#######################################
readonly VERSION_NIGHTLY="nightly"
readonly VERSION_PRERELEASE="prerelease"
readonly VERSION_LATEST="latest"

readonly GITHUB_API_URL="https://api.github.com/repos/neovim/neovim/releases"

# Colors for output
readonly COLOR_RESET=$(tput sgr0)
readonly COLOR_RED=$(tput setaf 1)
readonly COLOR_GREEN=$(tput setaf 2)
readonly COLOR_BLUE=$(tput setaf 4)

#######################################
# System Detection
####################################

detect_system_info() {
  ARCH=$(uname -m)
  OS=$(uname -s)
}

# Set variables based on OS and architecture
set_install_paths() {
  case "$OS-$ARCH" in
  "Darwin-x86_64")
    INSTALL_DIR="$HOME/Applications/nvim-macos-x86_64"
    PACKAGE_NAME="nvim-macos-x86_64.tar.gz"
    ;;
  "Darwin-arm64")
    INSTALL_DIR="$HOME/Applications/nvim-macos-arm64"
    PACKAGE_NAME="nvim-macos-arm64.tar.gz"
    ;;
  "Linux-x86_64")
    INSTALL_DIR="$HOME/.local/nvim-linux-x86_64"
    PACKAGE_NAME="nvim-linux-x86_64.tar.gz"
    ;;
  "Linux-aarch64")
    INSTALL_DIR="$HOME/.local/nvim-linux-arm64"
    PACKAGE_NAME="nvim-linux-arm64.tar.gz"
    ;;
  *)
    echo "Unsupported OS or architecture: $OS-$ARCH"
    exit 1
    ;;
  esac
}

add_nightly_suffix_if_needed() {
  local version_type="$1"
  if is_nightly_or_prerelease "$version_type"; then
    INSTALL_DIR="${INSTALL_DIR}-nightly"
  fi
}

#######################################
# Helper Functions
####################################

is_nightly_or_prerelease() {
  [[ "$1" == "$VERSION_NIGHTLY" || "$1" == "$VERSION_PRERELEASE" ]]
}

is_macos() {
  [[ "$OS" == "Darwin" ]]
}

# INSTALL_DIR will be removed during installation, so ensure it's not HOME
validate_install_dir_not_home() {
  local install_dir_real
  local home_real

  # Create a temporary directory so realpath works (for fresh installs)
  # This will be removed and recreated during the actual installation anyway
  if [[ ! -d "$INSTALL_DIR" ]]; then
    mkdir -p "$INSTALL_DIR"
  fi

  if is_macos; then
    # realpath on macOS does not support -m option
    install_dir_real=$(realpath "$INSTALL_DIR")
    home_real=$(realpath "$HOME")
  else
    install_dir_real=$(realpath -m "$INSTALL_DIR")
    home_real=$(realpath -m "$HOME")
  fi

  if [[ "$install_dir_real" == "$home_real" ]]; then
    echo "Error: Installation directory cannot be HOME."
    exit 1
  fi
}

#######################################
# Version Information Functions
####################################

fetch_nightly_version_info() {
  local response
  response=$(curl -s "$GITHUB_API_URL")

  version=$(echo "$response" | jq -r '.[] | select(.prerelease) | .body' | grep -Eo 'NVIM\s+\S+')
  download_url=$(echo "$response" | jq -r ".[] | select(.prerelease) | .assets[] | select(.name == \"$PACKAGE_NAME\") | .browser_download_url" | head -n 1)
  display_version="The latest Neovim nightly version is: ${COLOR_GREEN}$version${COLOR_RESET}"
}

fetch_latest_version_info() {
  local response
  response=$(curl -s "$GITHUB_API_URL/latest")

  version=$(echo "$response" | jq -r '.tag_name')
  version="NVIM $version"
  download_url=$(echo "$response" | jq -r ".assets[] | select(.name == \"$PACKAGE_NAME\") | .browser_download_url")
  display_version="The latest Neovim release version is: ${COLOR_GREEN}$version${COLOR_RESET}"
}

get_installed_version() {
  if [[ -x "$INSTALL_DIR/bin/nvim" ]]; then
    "$INSTALL_DIR/bin/nvim" --version | head -n 1 | grep -Eo 'NVIM\s+\S+'
  fi
}

print_version_info() {
  local version_type="$1"
  local installed_version="$2"

  echo "$display_version"

  if is_nightly_or_prerelease "$version_type"; then
    echo "Installed Neovim nightly version is:  ${COLOR_BLUE}$installed_version${COLOR_RESET}"
  else
    echo "Installed Neovim release version is:  ${COLOR_BLUE}$installed_version${COLOR_RESET}"
  fi
}

show_rate_limit_error() {
  local version_type="$1"
  echo "Error: Could not determine download URL or version for $version_type"
  echo
  echo "If you see an error like:"
  echo "  jq: error (at <stdin>:1): Cannot iterate over null (null)"
  echo "You have reached the GitHub API rate limit."
  echo "Please wait for a while and try again."
  echo
  return 1
}

#######################################
# Download and Installation Functions
####################################

download_neovim() {
  local download_url="$1"
  local package_path="/tmp/$PACKAGE_NAME"

  echo "Downloading from $download_url..."
  curl -L -o "$package_path" "$download_url"
}

extract_and_install_neovim() {
  local version_type="$1"
  local package_path="/tmp/$PACKAGE_NAME"

  echo "Extracting Neovim to $INSTALL_DIR..."

  # Clear macOS extended attributes to avoid quarantine warnings
  if is_macos; then
    xattr -c "$package_path"
  fi

  # Remove old installation and create fresh directory
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"

  # Extract to /tmp first
  cd "/tmp" || exit 1
  tar -xzf "$package_path" -C "/tmp"

  # Get the extracted directory name
  local extracted_dir
  extracted_dir=$(tar -tf "$package_path" | head -n 1 | cut -f1 -d"/")

  # Move to final location with appropriate naming
  if is_nightly_or_prerelease "$version_type"; then
    mv "/tmp/$extracted_dir" "/tmp/${extracted_dir}-nightly"
    mv "/tmp/${extracted_dir}-nightly" "$(dirname "$INSTALL_DIR")/"
  else
    mv "/tmp/$extracted_dir" "$(dirname "$INSTALL_DIR")/"
  fi

  # Clean up downloaded package
  rm -rf "$package_path"
}

print_installation_success() {
  local was_installed="$1"

  if [[ -z "$was_installed" ]]; then
    echo "Neovim ${COLOR_GREEN}installed successfully${COLOR_RESET}."
  else
    echo "Neovim ${COLOR_GREEN}updated successfully${COLOR_RESET}."
  fi
}

#######################################
# Main Installation Function
####################################

install_version() {
  local version_type="$1"
  local version
  local download_url
  local display_version

  # Fetch version and download URL based on type
  if is_nightly_or_prerelease "$version_type"; then
    fetch_nightly_version_info
  elif [[ "$version_type" == "$VERSION_LATEST" ]]; then
    fetch_latest_version_info
  else
    echo "Error: Invalid version type: $version_type"
    return 1
  fi

  # Validate we got the required information
  if [[ -z "$version" || -z "$download_url" ]]; then
    show_rate_limit_error "$version_type"
    return 1
  fi

  # Get current installed version
  local installed_version
  installed_version=$(get_installed_version)

  # Display version information
  print_version_info "$version_type" "$installed_version"

  # Check if update is needed
  if [[ "$version" == "$installed_version" ]]; then
    echo "The installed version is ${COLOR_GREEN}up to date${COLOR_RESET}."
    return 0
  fi

  # Proceed with installation/update
  if [[ -z "$installed_version" ]]; then
    echo "Neovim $version_type is not installed. Proceeding with installation..."
  else
    echo "The installed version is ${COLOR_RED}outdated${COLOR_RESET}. Installing the latest $version_type version..."
  fi

  # Download and install
  download_neovim "$download_url"
  extract_and_install_neovim "$version_type"
  print_installation_success "$installed_version"

  # Run post-installation actions
  post_install_actions "$version" "$version_type"
}

#######################################
# Post-Installation Actions
####################################

post_install_actions() {
  local installed_version="$1"
  local version_type="$2"

  # Print installation location
  if [[ -x "$INSTALL_DIR/bin/nvim" ]]; then
    echo "Neovim ${COLOR_GREEN}$installed_version${COLOR_RESET} has been installed to ${COLOR_BLUE}$INSTALL_DIR/bin/nvim${COLOR_RESET}"
  fi

  # Skip symlink creation for nightly/prerelease or on macOS
  if is_nightly_or_prerelease "$version_type" || is_macos; then
    return 0
  fi

  manage_system_symlink
}

manage_system_symlink() {
  # Remove existing symlink if present
  if [[ -L "/usr/bin/nvim" ]]; then
    echo "Removing existing symlink /usr/bin/nvim"
    sudo rm "/usr/bin/nvim"
  fi

  # Create new symlink
  if [[ ! -L "/usr/bin/nvim" ]]; then
    echo "Creating symlink /usr/bin/nvim to $INSTALL_DIR/bin/nvim"
    sudo ln -s "$INSTALL_DIR/bin/nvim" "/usr/bin/nvim"
  fi
}

#######################################
# Main Entry Point
####################################

main() {
  detect_system_info
  set_install_paths
  add_nightly_suffix_if_needed "${1:-$VERSION_LATEST}"
  validate_install_dir_not_home

  local version_type="${1:-$VERSION_LATEST}"

  case "$version_type" in
    "$VERSION_NIGHTLY" | "$VERSION_PRERELEASE" | "$VERSION_LATEST")
      install_version "$version_type"
      ;;
    *)
      echo "Error: Invalid argument '$version_type'. Use 'nightly', 'prerelease', or 'latest'."
      echo "Leaving empty defaults to 'latest'."
      exit 1
      ;;
  esac
}

main "$@"
