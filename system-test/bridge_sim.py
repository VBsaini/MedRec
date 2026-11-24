"""Plays the ESP32's part for the system test: runs the RFID bridge's real
serial loop on a simulated port that prints what the firmware prints when a
card is tapped. Usage: bridge_sim.py <url-prefix> <card-uid>
"""

import sys
import types
from pathlib import Path

prefix, uid = sys.argv[1], sys.argv[2]

# The firmware's output for one tap (see Firmware/MedRec_Reader).
LINES = [b"MEDREC_READER_READY\r\n", f"RFID_UID:{uid}\r\n".encode()]


class SimulatedPort:
    def __init__(self, port, baudrate, timeout):
        self.lines = list(LINES)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def reset_input_buffer(self):
        pass

    def readline(self):
        if self.lines:
            return self.lines.pop(0)
        raise KeyboardInterrupt  # stop, as Ctrl+C would


# pyserial may not be installed; the simulated port replaces it.
serial = types.ModuleType("serial")
serial.Serial = SimulatedPort
serial.SerialException = type("SerialException", (Exception,), {})
tools = types.ModuleType("serial.tools")
tools.list_ports = types.ModuleType("serial.tools.list_ports")
tools.list_ports.comports = lambda: []
serial.tools = tools
sys.modules.update({"serial": serial, "serial.tools": tools, "serial.tools.list_ports": tools.list_ports})

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Python"))
import rfid_bridge  # noqa: E402

rfid_bridge.time.sleep = lambda seconds: None  # no board to wait for
sys.exit(rfid_bridge.monitor("SIMULATED", 115200, prefix, "", "brave", no_browser=True))
