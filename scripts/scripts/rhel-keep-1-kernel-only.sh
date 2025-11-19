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

# Check if any old kernels were found
if [[ -z "$OLD_KERNELS" ]]; then
    echo "No old kernels found to remove."
    exit 0
fi

# Output if in dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry-run mode enabled. The following kernels would be removed:"
    echo "$OLD_KERNELS"
    echo "To actually remove the kernels, run the script without the '-d' or '--dry-run' option."
    exit 0
fi

# Loop through each old kernel and remove it
echo "Removing old kernels..."
while IFS= read -r kernel; do
    echo "Removing: $kernel"
    sudo dnf remove -y "$kernel"
done <<< "$OLD_KERNELS"

echo "Old kernels removal complete."

sudo grub2-mkconfig -o /boot/grub2/grub.cfg

echo "List of boot loader entries:"
sudo find "/boot/loader/entries" -maxdepth 1 | tail -n +2
