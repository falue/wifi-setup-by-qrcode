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
}}
            """)

        os.system(f"wpa_supplicant -i wlan0 -c {TEMP_WPA_FILE} -B")
        time.sleep(10)

        result = subprocess.run(["iwgetid"], capture_output=True, text=True)
        return ssid in result.stdout
    finally:
        os.system("killall wpa_supplicant")
        os.system(f"wpa_supplicant -i wlan0 -c {ORIGINAL_WPA_FILE} -B")

def connect_to_new_network():
    """
    Restart the Wi-Fi interface to connect to the new network.
    """
    os.system("sudo systemctl restart dhcpcd")
    os.system("sudo wpa_cli -i wlan0 reconfigure")
    time.sleep(5)  # Wait a few seconds for the connection
    result = subprocess.run(["iwgetid"], capture_output=True, text=True)
    
    if result.stdout:
        return True  # Successfully connected
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
            if connect_to_new_network():
                return render_template("index.html", message="Connected successfully! The Pi is now on the new network.")
            else:
                return render_template("index.html", error="Credentials saved, but failed to connect. Try rebooting.")
        
        return render_template("index.html", error="Failed to validate Wi-Fi. Check SSID and password.")

    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
