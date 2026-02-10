#!/usr/bin/env bash

set -euo pipefail

# Constants
readonly ENTRIES_DIR="/boot/loader/entries"
readonly GRUB_CFG="/boot/grub2/grub.cfg"

# Global state
DRY_RUN=false

# =============================================================================
# Helper Functions
# =============================================================================

show_help() {
  cat <<EOF
Usage: $0 [-d|--dry-run] [-h|--help]
Deletes old Linux kernels from the system.

Options:
  -d, --dry-run   Perform a dry-run (show what would be removed without actually removing).
  -h, --help      Show this help message.
EOF
  exit 0
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARNING: $*" >&2
}

info() {
  echo "$*"
}

# =============================================================================
# Kernel Version Functions
# =============================================================================

get_current_kernel() {
  uname -r
}

get_latest_installed_kernel() {
  rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1
}

check_kernel_version() {
  local current_kernel latest_kernel
  current_kernel=$(get_current_kernel)
  latest_kernel=$(get_latest_installed_kernel)

  if [[ "$current_kernel" != "$latest_kernel" ]]; then
    warn "Current running kernel ($current_kernel) is not the latest installed kernel ($latest_kernel)."
    die "Please reboot the server to boot into the latest kernel before removing old kernels."
  fi
}

get_old_kernels() {
  sudo dnf repoquery --installonly --installed --latest-limit=-1
}

# =============================================================================
# Boot Loader Entry Functions
# =============================================================================

extract_kernel_version_from_entry() {
  local entry="$1"
  if [[ "$entry" =~ ^[[:xdigit:]]{32}-(.+)\.conf$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

is_rescue_kernel_identifier() {
  local kernel_version="$1"
  [[ "$kernel_version" == 0-rescue* ]]
}

find_old_boot_loader_kernels() {
  local current_kernel current_conf ref_time current_entry_prefix
  current_kernel=$(get_current_kernel)

  # Get all entries
  local entries
  mapfile -t entries < <(sudo ls -1 "$ENTRIES_DIR")

  # Find config file for current kernel
  current_conf=""
  for entry in "${entries[@]}"; do
    if [[ "$entry" == *"$current_kernel.conf" ]]; then
      current_conf="$entry"
      break
    fi
  done

  if [[ -z "$current_conf" ]]; then
    warn "Could not find entry for current kernel ($current_kernel) in $ENTRIES_DIR"
    return 1
  fi
  current_entry_prefix="${current_conf%%-*}"

  # Get reference time from current kernel's config
  ref_time=$(sudo stat -c %Y "$ENTRIES_DIR/$current_conf")

  # Find kernel versions older than current kernel entry
  local old_kernels=()
  for entry in "${entries[@]}"; do
    local file_time
    file_time=$(sudo stat -c %Y "$ENTRIES_DIR/$entry")

    if [[ "$file_time" -lt "$ref_time" ]]; then
      local kernel_version
      if ! kernel_version=$(extract_kernel_version_from_entry "$entry"); then
        continue
      fi
      if is_rescue_kernel_identifier "$kernel_version"; then
        continue
      fi
      if [[ "$kernel_version" == "$current_kernel" ]]; then
        continue
      fi
      if [[ ! " ${old_kernels[*]} " =~ " ${kernel_version} " ]]; then
        old_kernels+=("$kernel_version")
      fi
    fi
  done

  printf '%s\n' "${old_kernels[@]}"
}

find_stale_rescue_files() {
  local current_kernel current_conf current_entry_prefix
  current_kernel=$(get_current_kernel)

  local entries
  mapfile -t entries < <(sudo ls -1 "$ENTRIES_DIR")

  current_conf=""
  for entry in "${entries[@]}"; do
    if [[ "$entry" == *"$current_kernel.conf" ]]; then
      current_conf="$entry"
      break
    fi
  done

  if [[ -z "$current_conf" ]]; then
    warn "Could not determine current boot entry prefix for rescue file cleanup."
    return 1
  fi
  current_entry_prefix="${current_conf%%-*}"

  local entry rescue_prefix
  for entry in "${entries[@]}"; do
    if [[ ! "$entry" =~ ^[[:xdigit:]]{32}-0-rescue\.conf$ ]]; then
      continue
    fi
    rescue_prefix="${entry%%-*}"
    if [[ "$rescue_prefix" == "$current_entry_prefix" ]]; then
      continue
    fi

    printf '%s\n' "$ENTRIES_DIR/$entry"

    if [[ -e "/boot/initramfs-0-rescue-${rescue_prefix}.img" ]]; then
      printf '%s\n' "/boot/initramfs-0-rescue-${rescue_prefix}.img"
    fi
    if [[ -e "/boot/vmlinuz-0-rescue-${rescue_prefix}" ]]; then
      printf '%s\n' "/boot/vmlinuz-0-rescue-${rescue_prefix}"
    fi
    if [[ -e "/boot/.vmlinuz-0-rescue-${rescue_prefix}.hmac" ]]; then
      printf '%s\n' "/boot/.vmlinuz-0-rescue-${rescue_prefix}.hmac"
    fi
  done
}

find_files_by_kernel() {
  local kernel_version="$1"
  if is_rescue_kernel_identifier "$kernel_version"; then
    return 0
  fi

  sudo find "$ENTRIES_DIR" -maxdepth 1 -type f -name "*-${kernel_version}.conf" -print0
  sudo find /boot -maxdepth 1 -type f \
    \( -name "vmlinuz-${kernel_version}" \
    -o -name "System.map-${kernel_version}" \
    -o -name "config-${kernel_version}" \
    -o -name "symvers-${kernel_version}*" \
    -o -name "initramfs-${kernel_version}*.img" \) \
    -print0
}

delete_file() {
  local file="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY-RUN] Would delete: $file"
  else
    info "Deleting: $file"
    sudo rm -f "$file"
  fi
}

# =============================================================================
# Main Operations
# =============================================================================

remove_old_kernels() {
  local old_kernels="$1"

  if [[ -z "$old_kernels" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY-RUN] Would remove kernels:"
    echo "$old_kernels" | sed 's/^/  /'
    return 0
  fi

  info "Removing old kernels..."
  while IFS= read -r kernel; do
    [[ -z "$kernel" ]] && continue
    info "Removing: $kernel"
    sudo dnf remove -y "$kernel"
  done <<< "$old_kernels"
}

collect_files_to_delete() {
  local current_kernel
  current_kernel=$(get_current_kernel)

  # Read kernel versions from stdin, output files to stdout
  # Returns 1 if current kernel files would be affected
  local kernel_version
  while IFS= read -r kernel_version; do
    [[ -z "$kernel_version" ]] && continue
    while IFS= read -r -d '' file; do
      echo "$file"
      if [[ "$file" == *"$current_kernel"* ]]; then
        return 1
      fi
    done < <(find_files_by_kernel "$kernel_version")
  done

  return 0
}

confirm_deletion() {
  local prompt="$1"
  local response

  read -r -p "$prompt [y/N] " response
  case "$response" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

remove_boot_loader_entries() {
  local kernels_input="$1"

  # Collect files and check for safety
  local files_output stale_rescue_output
  if ! files_output=$(echo "$kernels_input" | collect_files_to_delete); then
    local current_kernel
    current_kernel=$(get_current_kernel)
    die "Files for current kernel ($current_kernel) would be deleted! Aborting."
  fi

  if ! stale_rescue_output=$(find_stale_rescue_files); then
    die "Failed to identify stale rescue boot artifacts."
  fi
  if [[ -n "$stale_rescue_output" ]]; then
    files_output+=$'\n'"$stale_rescue_output"
  fi

  if [[ -z "$files_output" ]]; then
    info "No boot loader entry files found to delete."
    return 0
  fi

  # Convert to de-duplicated array
  local files_to_delete=()
  declare -A seen_files=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ -n "${seen_files[$file]+x}" ]]; then
      continue
    fi
    seen_files["$file"]=1
    files_to_delete+=("$file")
  done <<< "$files_output"

  # Display files
  info "The following boot loader files will be deleted:"
  printf '  %s\n' "${files_to_delete[@]}"
  echo ""
  info "Current kernel ($(get_current_kernel)) is safe and will NOT be deleted."
  echo ""

  # Handle dry-run or confirm deletion
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY-RUN] No files were deleted."
    return 0
  fi

  if ! confirm_deletion "Do you want to delete these files?"; then
    info "Aborted. No files were deleted."
    exit 0
  fi

  # Delete files
  for file in "${files_to_delete[@]}"; do
    delete_file "$file"
  done

  info "Old boot loader entries deleted."
}

update_grub() {
  info "Updating GRUB configuration..."
  sudo grub2-mkconfig -o "$GRUB_CFG"
}

show_remaining_entries() {
  info "Remaining boot loader entries:"
  sudo ls -1 "$ENTRIES_DIR"
}

run_dry_run() {
  local old_kernels="$1"

  info "Dry-run mode enabled."
  echo ""

  remove_old_kernels "$old_kernels"

  info "Checking for old boot loader entry files..."
  local old_boot_kernels
  if ! old_boot_kernels=$(find_old_boot_loader_kernels); then
    die "Failed to identify old boot loader entries."
  fi
  remove_boot_loader_entries "$old_boot_kernels"

  echo ""
  info "To actually remove the kernels, run without the '-d' or '--dry-run' option."
}

run_removal() {
  local old_kernels="$1"

  # Get old boot loader kernel versions
  local old_boot_kernels stale_rescue_files
  if ! old_boot_kernels=$(find_old_boot_loader_kernels); then
    die "Failed to identify old boot loader entries."
  fi
  if ! stale_rescue_files=$(find_stale_rescue_files); then
    die "Failed to identify stale rescue boot artifacts."
  fi

  # Check if there's anything to remove
  if [[ -z "$old_kernels" ]] && [[ -z "$old_boot_kernels" ]] && [[ -z "$stale_rescue_files" ]]; then
    info "No old kernels or boot loader entries found to remove."
    exit 0
  fi

  # Remove old kernels via dnf
  remove_old_kernels "$old_kernels"

  # Remove old boot loader entries
  remove_boot_loader_entries "$old_boot_kernels"

  info "Old kernels removal complete."

  # Update GRUB and show results
  update_grub
  show_remaining_entries
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -h|--help)
        show_help
        ;;
      *)
        die "Invalid argument: $1. Use -h for help."
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  check_kernel_version

  info "Retrieving list of old kernels..."
  local old_kernels
  old_kernels=$(get_old_kernels)

  if [[ "$DRY_RUN" == "true" ]]; then
    run_dry_run "$old_kernels"
  else
    run_removal "$old_kernels"
  fi
}

main "$@"
