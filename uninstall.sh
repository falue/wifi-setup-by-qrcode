#!/bin/bash

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root. Use: sudo bash uninstall.sh"
    exit 1
fi

echo "Starting uninstallation process..."

# Check if backup of dhcpcd.conf exists and restore it
if [[ -f /etc/dhcpcd.conf.backup ]]; then
    echo "Restoring original dhcpcd.conf..."
    sudo mv /etc/dhcpcd.conf.backup /etc/dhcpcd.conf
    sudo systemctl restart dhcpcd
    echo "dhcpcd.conf restored successfully."
else
    echo "No backup found for dhcpcd.conf. Skipping restoration."
fi

# Stop and disable services
echo "Disabling and stopping Wi-Fi setup services..."

sudo systemctl stop wifi-setup
sudo systemctl disable wifi-setup
sudo rm -f /etc/systemd/system/wifi-setup.service

sudo systemctl stop wifi-autoswitch
sudo systemctl disable wifi-autoswitch
sudo rm -f /etc/systemd/system/wifi-autoswitch.service
sudo rm -f /usr/local/bin/wifi-autoswitch.sh

echo "Disabling hostapd and dnsmasq services..."
sudo systemctl stop hostapd
sudo systemctl disable hostapd

sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq

echo "Uninstallation complete. Reboot to apply changes."
