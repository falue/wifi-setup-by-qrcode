#!/bin/bash

set -e  # Exit on error

# Detect the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Script is running from: $SCRIPT_DIR"

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root. Use: sudo bash wifi-setup.sh"
    exit 1
fi

echo "Updating system and installing required packages..."
# sudo apt update && sudo apt upgrade -y
sudo apt install -y hostapd dnsmasq python3-flask qrencode iw net-tools

echo "Stopping services before configuration..."
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

echo "Backing up existing dhcpcd.conf if not already backed up..."
if [[ ! -f /etc/dhcpcd.conf.backup ]]; then
    sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup
    echo "Backup created at /etc/dhcpcd.conf.backup"
else
    echo "Backup already exists, skipping..."
fi

echo "Adding static IP for wlan0 (Hotspot Mode: 192.168.4.1)..."
if ! grep -q "interface wlan0" /etc/dhcpcd.conf; then
    sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF

# Wi-Fi Hotspot Mode (Static IP)
interface wlan0
static ip_address=192.168.4.1/24
nohook wpa_supplicant
EOF
    echo "Static IP for Hotspot Mode added."
else
    echo "Hotspot Mode IP configuration already exists, skipping..."
fi

echo "Adding static IP for wlan0 (Client Mode: 192.168.1.100)..."
if ! grep -q "static ip_address=192.168.1.100" /etc/dhcpcd.conf; then
    sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF

# Wi-Fi Client Mode (Static IP)
interface wlan0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
EOF
    echo "Static IP for Client Mode added."
else
    echo "Client Mode IP configuration already exists, skipping..."
fi

echo "Adding static IP for eth0 (Static Ethernet Configuration)..."
if ! grep -q "interface eth0" /etc/dhcpcd.conf; then
    sudo tee -a /etc/dhcpcd.conf > /dev/null <<EOF

# Ethernet (Static IP)
interface eth0
static ip_address=192.168.1.50/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
EOF
    echo "Static IP for Ethernet added."
else
    echo "Ethernet configuration already exists, skipping..."
fi

echo "Restarting networking service to apply changes..."
sudo systemctl restart dhcpcd

echo "Configuring dnsmasq (DHCP server for hotspot mode)..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF

echo "Configuring hostapd (Wi-Fi Access Point)..."
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=PiSetup
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

echo "Setting hostapd default configuration..."
sudo tee -a /etc/default/hostapd > /dev/null <<EOF
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF

echo "Enabling and starting hostapd and dnsmasq..."
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl start hostapd
sudo systemctl start dnsmasq

echo "Ensuring Flask app directory exists at $SCRIPT_DIR"
mkdir -p "$SCRIPT_DIR"

echo "Checking if Flask app (app.py) exists..."
if [[ ! -f "$SCRIPT_DIR/app.py" ]]; then
    echo "Error: app.py not found in $SCRIPT_DIR. Please add your Flask application."
    exit 1
fi

echo "Checking if index.html exists in templates/..."
if [[ ! -f "$SCRIPT_DIR/templates/index.html" ]]; then
    echo "Error: index.html not found in $SCRIPT_DIR/templates/. Please add your HTML file."
    exit 1
fi

echo "Generating QR code for Wi-Fi setup page..."
qrencode -t SVG -o "$SCRIPT_DIR/qrcode.svg" "http://192.168.4.1"

echo "Creating systemd service for the Flask app..."
sudo tee /etc/systemd/system/wifi-setup.service > /dev/null <<EOF
[Unit]
Description=Wi-Fi Setup Flask App
After=network.target

[Service]
ExecStart=/usr/bin/python3 $SCRIPT_DIR/app.py
WorkingDirectory=$SCRIPT_DIR
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting Wi-Fi setup service..."
sudo systemctl enable wifi-setup
sudo systemctl start wifi-setup

echo "Setting up auto-switching between Wi-Fi client mode and hotspot mode..."
sudo tee /etc/systemd/system/wifi-autoswitch.service > /dev/null <<EOF
[Unit]
Description=Wi-Fi Auto Switch
After=network.target

[Service]
ExecStart=/usr/local/bin/wifi-autoswitch.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo tee /usr/local/bin/wifi-autoswitch.sh > /dev/null <<EOF
#!/bin/bash

while true; do
    if iwgetid -r > /dev/null; then
        echo "Connected to Wi-Fi, disabling hotspot..."
        systemctl stop hostapd
        systemctl stop dnsmasq
    else
        echo "No Wi-Fi connection, enabling hotspot..."
        systemctl start hostapd
        systemctl start dnsmasq
    fi
    sleep 30
done
EOF

chmod +x /usr/local/bin/wifi-autoswitch.sh
sudo systemctl enable wifi-autoswitch.service
sudo systemctl start wifi-autoswitch.service

echo "Setup complete! Reboot to test."
