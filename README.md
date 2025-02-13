# Wifi Setup by QR code

> ***WIP:*** This does not work yet.

This script installs & set ups everything needed for a headless raspberry pi
to be connected to a known wifi by a user without ssh knowledge.

## How It Works
1. The script sets up a Wi-Fi hotspot on the Raspberry Pi.
2. It generates a QR code that can be printed and scanned with a mobile device.
3. When scanned, it opens a local webpage (`http://192.168.4.1`), where the user can enter Wi-Fi credentials.
4. The Raspberry Pi auto-connects to the entered Wi-Fi without requiring a reboot.

## Fixed IP Addresses
To ensure reliable access, the Raspberry Pi always uses these static IPs:

- Hotspot Mode: `192.168.4.1` → Used when no known Wi-Fi is available (this is where the QR code points).
- Client Mode: `192.168.1.100` → Used when connected to a router.

## Auto-Start on Boot
- The script ensures the Flask web server and hotspot service start on every boot, even if Wi-Fi is already set up.
- This allows users to update Wi-Fi credentials at any time.

# Run install once
```bash wifi-setup.sh```

# Testing
Run with `bash -x wifi-setup.sh` to test step-by-step.