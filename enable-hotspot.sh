#!/bin/bash

set -e  # Exit on error

echo "Enabling the hotspot..."

# Start hostapd and dnsmasq (hotspot services)
sudo systemctl start hostapd
sudo systemctl start dnsmasq

# Ensure dhcpcd is running
sudo systemctl restart dhcpcd

echo "Hotspot is enabled. The Pi should now be broadcasting 'PiSetup'."
