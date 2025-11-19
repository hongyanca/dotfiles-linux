#!/usr/bin/env bash

# Get the distro ID from /etc/os-release
distro_id=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')

# Check if the distro is "ubuntu"
if [ "$distro_id" != "ubuntu" ]; then
  echo "This script requires Ubuntu. Exiting."
  exit 1
fi

sudo pro config set apt_news=false
sudo apt remove ubuntu-advantage-tools -y
sudo ln -s -f /dev/null /etc/apt/apt.conf.d/20apt-esm-hook.conf
sudo sed -i'' -e 's/^\(\s\+\)\([^#]\)/\1# \2/' /etc/apt/apt.conf.d/20apt-esm-hook.conf
sudo mv -v /etc/apt/apt.conf.d/20apt-esm-hook.conf /etc/apt/apt.conf.d/20apt-esm-hook.conf-$(date +%Y%m%d)

# Mask the service units from systemd
sudo systemctl mask apt-news.service
sudo systemctl mask esm-cache.service

# Disable the ESM hook using dpkg-divert
sudo dpkg-divert --rename --divert /etc/apt/apt.conf.d/20apt-esm-hook.conf.disabled --add /etc/apt/apt.conf.d/20apt-esm-hook.conf

# Disable ubuntu-advantage service
sudo systemctl disable ubuntu-advantage

# Modify /etc/default/motd-news to disable motd-news
if [ -f /etc/default/motd-news ]; then
  sudo sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news
  echo "Disabled motd-news in /etc/default/motd-news."
else
  echo "/etc/default/motd-news not found."
fi

# Neuter the functions that generate the messages
sudo sed -Ezi.orig \
  -e 's/(def _output_esm_service_status.outstream, have_esm_service, service_type.:\n)/\1    return\n/' \
  -e 's/(def _output_esm_package_alert.*?\n.*?\n.:\n)/\1    return\n/' \
  /usr/lib/update-notifier/apt_check.py

sudo pro disable esm-apps
sudo rm /var/lib/update-notifier/updates-available
sudo rm -f /etc/apt/apt.conf.d/20apt-esm-hook.conf*

echo "Logout and log back in."
