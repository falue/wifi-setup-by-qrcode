from flask import Flask, request, render_template, jsonify
import os
import subprocess
import time

app = Flask(__name__, template_folder="templates")

TEMP_WPA_FILE = "/run/wpa_supplicant.conf"
ORIGINAL_WPA_FILE = "/etc/wpa_supplicant/wpa_supplicant.conf"

def validate_wifi_credentials(ssid, password):
    """
    Validate Wi-Fi credentials by attempting a temporary connection.
    """
    try:
        with open(TEMP_WPA_FILE, "w") as temp_conf:
            temp_conf.write(f"""ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={{
    ssid="{ssid}"
    psk="{password}"
    key_mgmt=WPA-PSK
}}
""")

        # Start temporary Wi-Fi connection
        os.system(f"sudo wpa_supplicant -B -i wlan0 -c {TEMP_WPA_FILE}")

        # Wait up to 15 seconds for a successful connection
        for _ in range(15):
            result = subprocess.run(["iwgetid", "-r"], capture_output=True, text=True)
            if ssid in result.stdout.strip():
                return True  # Connection successful
            time.sleep(1)  # Wait 1 second before checking again

        return False  # Timeout, connection failed

    finally:
        # Kill temporary `wpa_supplicant` session and restore original settings
        os.system("sudo pkill wpa_supplicant")
        os.system(f"sudo wpa_supplicant -B -i wlan0 -c {ORIGINAL_WPA_FILE}")

def connect_to_wifi():
    """ Reloads Wi-Fi settings and attempts connection using existing wpa_supplicant.conf. """
    # Restart Wi-Fi services to apply the new network configuration
    os.system("sudo systemctl restart wpa_supplicant")
    os.system("sudo systemctl restart dhcpcd")

    # Wait for Wi-Fi connection to establish
    time.sleep(15)

    # Check if successfully connected
    result = subprocess.run(["iwgetid", "-r"], capture_output=True, text=True)
    return bool(result.stdout.strip())  # Returns True if connected, False otherwise

    
def append_wifi_network(ssid, password):
    """
    Append a new Wi-Fi network to wpa_supplicant.conf while keeping the required settings.
    """
    config_block = f"""
    network={{
        ssid="{ssid}"
        psk="{password}"
        key_mgmt=WPA-PSK
    }}
    """
    with open(ORIGINAL_WPA_FILE, "r") as f:
        config = f.read()

    # Ensure the base settings exist
    if "ctrl_interface=" not in config:
        config = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=US\n" + config

    # Append the new Wi-Fi network
    with open(ORIGINAL_WPA_FILE, "w") as f:
        f.write(config.strip() + "\n" + config_block)

    # Restart networking services
    os.system("sudo systemctl restart wpa_supplicant")
    os.system("sudo systemctl restart dhcpcd")


@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        ssid = request.form["ssid"]
        password = request.form["password"]

        if not ssid:
            return jsonify({"error": "SSID cannot be empty"}), 400

        # Show loading message (via JavaScript)
        if validate_wifi_credentials(ssid, password):
            # Apply new settings
            append_wifi_network(ssid, password)
            
            # Try to Connect
            if connect_to_wifi():
                return jsonify({"message": "Connected successfully! The Pi is now on the new network."})
            else:
                return jsonify({"error": "Credentials saved, but failed to connect. Try rebooting."}), 500

        return jsonify({"error": "Failed to validate Wi-Fi. Check SSID and password."}), 400

    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
