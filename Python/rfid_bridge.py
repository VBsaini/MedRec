#!/usr/bin/env python3
"""Read ESP32 RFID UID messages and open the matching MedRec page in Brave."""

import argparse
import os
import re
import shutil
import sys
import time
import webbrowser
from pathlib import Path
from urllib.parse import quote, urlsplit

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    print("pyserial is required. Install it with: python -m pip install -r Python/requirements.txt", file=sys.stderr)
    raise SystemExit(1)


BAUD_RATE = 115200
DEFAULT_URL_PREFIX = os.environ.get(
    "MEDREC_URL_PREFIX", "http://localhost:5173/record/"
)
DEFAULT_URL_SUFFIX = os.environ.get("MEDREC_URL_SUFFIX", "")
PORT_HINTS = (
    "ch340",
    "cp210",
    "usb serial",
    "usbserial",
    "usbmodem",
    "usb jtag",
    "esp32",
    "uart",
    "wch",
    "slab",
)


def find_esp32_port():
    """Return a likely ESP32 serial port, or None if no USB serial device matches."""
    for port in list_ports.comports():
        description = " ".join(
            filter(None, (port.device, port.description, port.manufacturer, port.hwid))
        ).lower()
        if any(hint in description for hint in PORT_HINTS):
            return port.device
    return None


def list_serial_ports():
    ports = list(list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return

    print("Available serial ports:")
    for port in ports:
        print(f"  {port.device}: {port.description}")


def build_record_url(uid, prefix, suffix):
    """Build a URL from a trusted site prefix and a card UID read over serial."""
    normalized_uid = uid.strip().upper()
    if not re.fullmatch(r"[A-Z0-9_-]{1,64}", normalized_uid):
        raise ValueError("UID must contain 1–64 letters, digits, underscores, or hyphens.")

    parts = urlsplit(prefix)
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise ValueError("URL prefix must be an absolute http:// or https:// URL.")

    url = f"{prefix}{quote(normalized_uid, safe='')}{suffix}"
    final_parts = urlsplit(url)
    if final_parts.scheme not in ("http", "https") or not final_parts.netloc:
        raise ValueError("The URL prefix and suffix did not produce a valid website URL.")
    return url


def find_brave_executable():
    """Find a Brave executable on PATH or in common desktop install locations."""
    for command in ("brave", "brave-browser", "brave-browser-stable"):
        executable = shutil.which(command)
        if executable:
            return executable

    if sys.platform == "darwin":
        candidates = (
            Path("/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"),
            Path.home() / "Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
        )
    elif os.name == "nt":
        candidates = (
            Path(os.environ.get("PROGRAMFILES", "C:/Program Files"))
            / "BraveSoftware/Brave-Browser/Application/brave.exe",
            Path(os.environ.get("PROGRAMFILES(X86)", "C:/Program Files (x86)"))
            / "BraveSoftware/Brave-Browser/Application/brave.exe",
            Path(os.environ.get("LOCALAPPDATA", ""))
            / "BraveSoftware/Brave-Browser/Application/brave.exe",
        )
    else:
        candidates = (
            Path("/usr/bin/brave"),
            Path("/usr/bin/brave-browser"),
            Path("/snap/bin/brave"),
            Path("/opt/brave.com/brave/brave-browser"),
        )

    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    return None


def open_url(url, browser_name):
    if browser_name == "default":
        opened = webbrowser.open(url, new=2, autoraise=True)
        if not opened:
            raise RuntimeError("The system default browser did not accept the URL.")
        return

    executable = find_brave_executable()
    if not executable:
        raise RuntimeError(
            "Brave Browser was not found. Install Brave, add it to PATH, or run with --browser default."
        )

    brave = webbrowser.BackgroundBrowser(executable)
    if not brave.open(url, new=2, autoraise=True):
        raise RuntimeError("Brave Browser did not accept the URL.")


def handle_line(line, prefix, suffix, browser_name, no_browser):
    line = line.strip()
    if not line:
        return

    if line == "MEDREC_READER_READY":
        print("ESP32 RFID reader is ready.")
        return

    if line.startswith("RFID_UID:"):
        uid = line.partition(":")[2].strip()
        try:
            url = build_record_url(uid, prefix, suffix)
        except ValueError as error:
            print(f"Ignored invalid card message: {error}", file=sys.stderr)
            return

        print(f"Card {uid.upper()} detected: {url}")
        if not no_browser:
            try:
                open_url(url, browser_name)
            except (OSError, RuntimeError, webbrowser.Error) as error:
                print(f"Could not open the record page: {error}", file=sys.stderr)
        return

    # Keep startup/debug messages visible without mistaking them for card UIDs.
    print(f"[ESP32] {line}")


def monitor(port, baud, prefix, suffix, browser_name, no_browser):
    print(f"Connecting to {port} at {baud} baud...")
    try:
        with serial.Serial(port, baudrate=baud, timeout=1) as connection:
            # Opening a USB serial connection can reset many ESP32 boards. Allow
            # the board to restart before displaying its startup message.
            time.sleep(2)
            connection.reset_input_buffer()
            print("Connected. Tap a card on the RC522 reader; press Ctrl+C to stop.")

            while True:
                raw_line = connection.readline()
                if not raw_line:
                    continue
                line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
                handle_line(line, prefix, suffix, browser_name, no_browser)
    except serial.SerialException as error:
        print(f"Serial connection error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nRFID bridge stopped.")
    return 0


def parse_args():
    parser = argparse.ArgumentParser(
        description="Open a MedRec record in Brave when an ESP32 reads an RFID card."
    )
    parser.add_argument("--port", "-p", help="ESP32 serial port, such as COM3 or /dev/cu.usbserial-0001")
    parser.add_argument("--baud", "-b", type=int, default=BAUD_RATE, help="Serial speed (default: %(default)s)")
    parser.add_argument("--list", "-l", action="store_true", help="List serial ports and exit")
    parser.add_argument(
        "--prefix",
        "--url-prefix",
        default=DEFAULT_URL_PREFIX,
        help="URL prefix before the card UID (default: %(default)s)",
    )
    parser.add_argument(
        "--suffix",
        "--url-suffix",
        default=DEFAULT_URL_SUFFIX,
        help="Optional URL suffix after the card UID",
    )
    parser.add_argument(
        "--browser",
        choices=("brave", "default"),
        default="brave",
        help="Browser to open (default: Brave)",
    )
    parser.add_argument("--no-browser", action="store_true", help="Print record URLs without opening them")
    return parser.parse_args()


def main():
    args = parse_args()
    if args.list:
        list_serial_ports()
        return 0

    port = args.port or find_esp32_port()
    if not port:
        print("No ESP32 serial port detected. Use --list, then pass --port PORT.", file=sys.stderr)
        return 2

    return monitor(
        port,
        args.baud,
        args.prefix,
        args.suffix,
        args.browser,
        args.no_browser,
    )


if __name__ == "__main__":
    raise SystemExit(main())
