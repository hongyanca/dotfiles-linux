#!/usr/bin/env bash

# Get the currently running kernel version
current_kernel=$(uname -r)

# Get the list of installed kernels
installed_kernels=$(dpkg --list | grep linux-image | awk '{ print $2 }' | grep -Eo '6\.[0-9]+\.[0-9]+-[0-9]+-generic' | sort -V)

# Define how many latest kernels to keep
keep_latest=1

# Convert the list of installed kernels into an array
kernel_array=($installed_kernels)

# Determine how many kernels are installed
num_kernels=${#kernel_array[@]}

# If there are more kernels than we want to keep, delete the oldest ones
if [[ $num_kernels -gt $keep_latest ]]; then
    # Get the list of kernels to remove (excluding the latest N and the current one)
    remove_kernels=()
    for kernel in "${kernel_array[@]:0:$((num_kernels - keep_latest))}"; do
        if [[ "$kernel" != "$current_kernel" ]]; then
            remove_kernels+=("$kernel")
        fi
    done

    # If there are kernels to remove, display a warning and ask for confirmation
    if [[ ${#remove_kernels[@]} -gt 0 ]]; then
        echo "The following old kernels will be removed:"
        for kernel in "${remove_kernels[@]}"; do
            echo "  - $kernel"
        done

        # Ask for user confirmation
        read -rp "Do you want to proceed? (y/Y to confirm): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Aborted. No kernels were removed."
            exit 1
        fi

        # Proceed with removal
        for kernel in "${remove_kernels[@]}"; do
            echo "Removing old kernel: $kernel"
            sudo apt-get -y purge "linux-image-$kernel" "linux-headers-$kernel" "linux-modules-$kernel"
        done

        # Clean up unneeded packages
        echo "Cleaning up..."
        sudo apt-get -y autoremove
        sudo apt-get -y clean
    else
        echo "No old kernels to remove."
    fi
else
    echo "No old kernels to remove."
fi
