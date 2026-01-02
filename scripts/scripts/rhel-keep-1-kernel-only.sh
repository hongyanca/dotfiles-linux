#!/usr/bin/env bash

# Set a flag to indicate dry-run mode
DRY_RUN=false

# Function to display help message
show_help() {
  echo "Usage: $0 [-d|--dry-run] [-h|--help]"
  echo "Deletes old Linux kernels from the system."
  echo ""
  echo "Options:"
  echo "  -d, --dry-run   : Perform a dry-run (show what would be removed without actually removing)."
  echo "  -h, --help      : Show this help message."
  exit 1
}

# Function to find old kernel hashes and return them as an array
# Usage: mapfile -t old_hashes < <(find_old_boot_loader_entries)
find_old_boot_loader_entries() {
  local entries_dir="/boot/loader/entries"

  # Get all entries
  mapfile -t entries < <(sudo ls -1 "$entries_dir")

  # Find current kernel version
  local current_kernel
  current_kernel=$(uname -r)

  # Locate the reference .conf file for the current kernel
  local current_conf=""
  for entry in "${entries[@]}"; do
    if [[ "$entry" == *"$current_kernel.conf" ]]; then
      current_conf="$entry"
      break
    fi
  done

  if [[ -z "$current_conf" ]]; then
    echo "Error: Could not find entry for current kernel ($current_kernel) in $entries_dir" >&2
    return 1
  fi

  # Get the modification time of the current kernel's config
  local ref_time
  ref_time=$(sudo stat -c %Y "$entries_dir/$current_conf")

  # Find old hashes
  local old_hashes=()
  for entry in "${entries[@]}"; do
    local file_path="$entries_dir/$entry"
    local file_time
    file_time=$(sudo stat -c %Y "$file_path")

    if [[ "$file_time" -lt "$ref_time" ]]; then
      local hash="${entry%%-*}"
      if [[ ! " ${old_hashes[*]} " =~ " ${hash} " ]]; then
        old_hashes+=("$hash")
      fi
    fi
  done

  # Output each hash on a separate line for mapfile consumption
  for hash in "${old_hashes[@]}"; do
    echo "$hash"
  done
}

# Function to delete old boot loader entries by hash
# Args: $1 = dry_run (true/false), $2... = hashes to delete
del_old_boot_loader_entries() {
  local dry_run="$1"
  shift
  local old_hashes=("$@")
  local entries_dir="/boot/loader/entries"

  if [[ ${#old_hashes[@]} -eq 0 ]]; then
    echo "No old kernel hashes found."
    return 0
  fi

  # Find and delete files with old hashes in /boot/loader/entries/ and /boot/
  for hash in "${old_hashes[@]}"; do
    # Delete from /boot/loader/entries/
    while IFS= read -r -d '' file; do
      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] Would delete: $file"
      else
        echo "Deleting: $file"
        sudo rm -f "$file"
      fi
    done < <(sudo find "$entries_dir" -maxdepth 1 -name "*${hash}*" -print0)

    # Delete from /boot/
    while IFS= read -r -d '' file; do
      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] Would delete: $file"
      else
        echo "Deleting: $file"
        sudo rm -f "$file"
      fi
    done < <(sudo find /boot -maxdepth 1 -name "*${hash}*" -print0)
  done

  echo "-----------------------------------"
  if [[ "$dry_run" == "true" ]]; then
    echo "Dry-run complete. No files were deleted."
  else
    echo "Old kernel files deletion complete."
  fi
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  -d | --dry-run)
    DRY_RUN=true
    shift
    ;;
  -h | --help)
    show_help
    ;;
  *)
    echo "Invalid argument: $1"
    show_help
    ;;
  esac
done

echo "Retrieving list of old kernels..."
# Get a list of old kernels to remove
OLD_KERNELS=$(sudo dnf repoquery --installonly --latest-limit=-1)

# Output if in dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry-run mode enabled."
  if [[ -n "$OLD_KERNELS" ]]; then
    echo "[DRY-RUN] Would delete: $OLD_KERNELS"
  fi
  echo "Checking for old boot loader entry files..."
  mapfile -t old_hashes < <(find_old_boot_loader_entries)
  del_old_boot_loader_entries "true" "${old_hashes[@]}"
  echo ""
  echo "To actually remove the kernels, run the script without the '-d' or '--dry-run' option."
  exit 0
fi

# Check if any old kernels or boot loader entries were found
mapfile -t old_hashes < <(find_old_boot_loader_entries)
if [[ -z "$OLD_KERNELS" ]] && [[ ${#old_hashes[@]} -eq 0 ]]; then
  echo "No old kernels or boot loader entries found to remove."
  exit 0
fi

# Loop through each old kernel and remove it
if [[ -n "$OLD_KERNELS" ]]; then
  echo "Removing old kernels..."
  while IFS= read -r kernel; do
    echo "Removing: $kernel"
    sudo dnf remove -y "$kernel"
  done <<<"$OLD_KERNELS"
fi

echo "Deleting old boot loader entries..."
del_old_boot_loader_entries "false" "${old_hashes[@]}"

echo "Old kernels removal complete."

sudo grub2-mkconfig -o /boot/grub2/grub.cfg

echo "List of boot loader entries:"
sudo find "/boot/loader/entries" -maxdepth 1 | tail -n +2
