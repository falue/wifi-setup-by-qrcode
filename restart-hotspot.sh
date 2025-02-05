#!/bin/bash

set -e  # Exit on error

echo "Stopping Wi-Fi-related services..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
sudo systemctl stop dhcpcd
sudo systemctl stop wpa_supplicant
sudo systemctl stop wifi-setup
sudo systemctl stop dual-ip.service

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Ensuring services are enabled on boot..."
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable dhcpcd
sudo systemctl enable wpa_supplicant
sudo systemctl enable wifi-setup
sudo systemctl enable dual-ip.service

echo "Restarting Wi-Fi services..."
sudo systemctl restart dhcpcd
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq
sudo systemctl restart wpa_supplicant
sudo systemctl restart dual-ip.service
sudo systemctl restart wifi-setup

echo "Checking active Wi-Fi interfaces..."
hostname -I

echo "Wi-Fi services restarted successfully!"
