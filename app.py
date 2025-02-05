from flask import Flask, request, render_template
import os
import subprocess
import time

app = Flask(__name__, template_folder="templates")

TEMP_WPA_FILE = "/tmp/wpa_supplicant.conf"
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


def connect_to_wifi(ssid, password):
    """ Writes Wi-Fi credentials to wpa_supplicant and attempts connection. """
    wifi_config = f"""
    network={{
        ssid="{ssid}"
        psk="{password}"
        key_mgmt=WPA-PSK
    }}
    """
    with open("/etc/wpa_supplicant/wpa_supplicant.conf", "w") as file:
        file.write(wifi_config)

    # Restart Wi-Fi service
    os.system("sudo systemctl restart wpa_supplicant")
    os.system("sudo systemctl restart dhcpcd")

    # Wait for Wi-Fi connection
    time.sleep(10)

    # Check if connected
    result = subprocess.run(["iwgetid", "-r"], capture_output=True, text=True)
    if result.stdout.strip():
        return True  # Successfully connected
    else:
        return False  # Connection failed

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        ssid = request.form["ssid"]
        password = request.form["password"]

        if validate_wifi_credentials(ssid, password):
            with open(ORIGINAL_WPA_FILE, "a") as f:
                f.write(f'\nnetwork={{\n    ssid="{ssid}"\n    psk="{password}"\n}}')

            # Apply new settings and connect immediately
            if connect_to_wifi():
                return render_template("index.html", message="Connected successfully! The Pi is now on the new network.")
            else:
                return render_template("index.html", error="Credentials saved, but failed to connect. Try rebooting.")
        
        return render_template("index.html", error="Failed to validate Wi-Fi. Check SSID and password.")

    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
