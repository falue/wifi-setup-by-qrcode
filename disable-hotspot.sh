#!/bin/bash

set -e  # Exit on error

echo "Temporarily disabling the hotspot..."

# Stop hostapd and dnsmasq (hotspot services)
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Restart wpa_supplicant to connect to a normal Wi-Fi network
sudo systemctl restart wpa_supplicant

# Restart dhcpcd to ensure normal Wi-Fi mode
sudo systemctl restart dhcpcd

echo "Hotspot is disabled. The Pi should now connect to regular Wi-Fi."
