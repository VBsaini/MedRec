import serial
import serial.tools.list_ports
import webbrowser
import time
import sys
import argparse

# ================= CONFIGURATION =================
# Default serial port (auto-detected if not specified)
DEFAULT_PORT = None  # e.g., "COM3"

# Baud rate (must match ESP32 sketch)
BAUD_RATE = 115200

# Frontend URL pattern
# The card UID will be appended to open the record
FRONTEND_BASE_URL = "http://localhost:5173/record/"

# Or if using the backend directly (for testing):
# FRONTEND_BASE_URL = "http://localhost:3000/record/"

# Auto-open browser on card tap
AUTO_OPEN_BROWSER = True

# Logging
LOG_TO_FILE = True
LOG_FILE = "medrec_access.log"

# =================================================


def find_esp32_port():
    """Auto-detect ESP32 serial port."""
    ports = serial.tools.list_ports.comports()
    for port in ports:
        # Common ESP32 identifiers
        if any(id in (port.description or "").lower() for id in 
               ["ch340", "cp210", "usb serial", "esp32", "uart"]):
            return port.device
    return None


def log_access(uid, status, name=None):
    """Log card access attempts."""
    if not LOG_TO_FILE:
        return
    from datetime import datetime
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] UID={uid} Status={status}"
    if name:
        entry += f" Name={name}"
    with open(LOG_FILE, "a") as f:
        f.write(entry + "\n")
    print(entry)


def open_browser(uid):
    """Open the medical record in the default browser."""
    url = FRONTEND_BASE_URL + uid
    print(f"Opening browser: {url}")
    webbrowser.open(url, new=2)  # new=2 opens in new tab if possible


def monitor(port, baud):
    """Main monitoring loop."""
    print(f"Connecting to {port} at {baud} baud...")
    
    try:
        ser = serial.Serial(port, baud, timeout=1)
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    print(f"Connected! Monitoring for RFID taps...")
    print("-" * 50)
    
    buffer = ""
    
    try:
        while True:
            if ser.in_waiting > 0:
                char = ser.read().decode('utf-8', errors='ignore')
                if char == '\n':
                    line = buffer.strip()
                    buffer = ""
                    
                    if line.startswith("RECORD_FOUND:"):
                        uid = line.split(":", 1)[1]
                        log_access(uid, "FOUND")
                        if AUTO_OPEN_BROWSER:
                            open_browser(uid)
                    
                    elif line.startswith("NO_RECORD:"):
                        uid = line.split(":", 1)[1]
                        log_access(uid, "NOT_REGISTERED")
                        print(f"⚠ Card {uid} is not registered in the system!")
                    
                    elif line.startswith("HTTP_ERROR:"):
                        code = line.split(":", 1)[1]
                        log_access("N/A", f"HTTP_{code}")
                        print(f"⚠ Server error (HTTP {code}). Is the backend running?")
                    
                    elif line.startswith("Card tapped:"):
                        uid = line.split(":", 1)[1].strip()
                        print(f"Card detected: {uid}")
                
                elif char != '\r':
                    buffer += char
            
            time.sleep(0.01)  # Small delay to prevent CPU spinning
            
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user.")
    finally:
        ser.close()
        print("Serial port closed.")


def list_ports():
    """List available serial ports."""
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for port in ports:
        print(f"  {port.device}: {port.description}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MedRec RFID-to-Browser Bridge")
    parser.add_argument("--port", "-p", help="Serial port (e.g., COM3)")
    parser.add_argument("--baud", "-b", type=int, default=BAUD_RATE, help="Baud rate")
    parser.add_argument("--list", "-l", action="store_true", help="List available ports")
    parser.add_argument("--no-browser", action="store_true", help="Disable auto browser open")
    parser.add_argument("--url", "-u", help="Frontend base URL")
    
    args = parser.parse_args()
    
    if args.list:
        list_ports()
        sys.exit(0)
    
    port = args.port or DEFAULT_PORT or find_esp32_port()
    
    if not port:
        print("No ESP32 detected! Use --list to see available ports or specify --port.")
        sys.exit(1)
    
    if args.no_browser:
        AUTO_OPEN_BROWSER = False
    
    if args.url:
        FRONTEND_BASE_URL = args.url
    
    monitor(port, args.baud)
