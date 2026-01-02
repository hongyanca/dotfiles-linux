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

# Function to clean package manager cache
purge_pkg_mgr_cache() {
  case "$LINUX_DISTRO" in
  "rhel" | "fedora")
    sudo dnf clean all
    ;;
  "arch")
    sudo pacman -Sc --noconfirm
    ;;
  "debian")
    sudo apt-get clean
    ;;
  *)
    echo "Error: Unsupported Linux distribution."
    return 1
    ;;
  esac

  return 0
}
purge_pkg_mgr_cache

echo "Resetting the cloud-init configuration to a clean state..."
sudo cloud-init clean
sudo rm -rf /var/lib/cloud/instances

## Function to clear history for a specific shell
clear_history() {
  local shell_name="$1"
  local history_file="$2"
  local hist_command="$3"
  local unset_vars="$4"

  # 1. Clear the history file on the disk
  if [ -f "$history_file" ]; then
    echo "Clearing file: ${history_file}"
    # Empty the file without deleting it (preserves permissions/inode)
    >$history_file
  else
    echo "History file not found: ${history_file}"
  fi

  # 2. Clear the in-memory history for the current session
  # Execute the history command
  eval "$hist_command"

  # Unset related variables to prevent history from being saved when the script exits
  if [ ! -z "$unset_vars" ]; then
    for var in $unset_vars; do
      unset "$var"
      echo "Unset variable: $var"
    done
  fi

  echo "Completed ${shell_name} history cleanup."
  echo ""
}

# --- Bash History Cleanup ---
clear_history \
  "Bash" \
  "$HOME/.bash_history" \
  "history -c" \
  "HISTFILE HISTSIZE HISTFILESIZE"

# --- Zsh History Cleanup ---
clear_history \
  "Zsh" \
  "$HOME/.zsh_history" \
  "history -p" \
  "HISTFILE HISTSIZE SAVEHIST"
rm -f "$HOME/.zcompdump*"

# Clear mise cache if available
if command -v mise &>/dev/null; then
  echo "Clearing mise cache..."
  mise cache clear
  echo
fi

# Check for the 'noshutdown' argument
if [[ "$1" != "noshutdown" ]]; then
  echo "Shutting down system in 3 seconds..."
  sleep 3
  sudo shutdown -h now
else
  echo "Skipping shutdown as 'noshutdown' argument is present."
fi
