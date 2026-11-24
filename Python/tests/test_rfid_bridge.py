"""Unit tests for the RFID bridge. Run from the project root:

    python -m unittest discover -s Python/tests -v

pyserial is replaced with a stand-in, so neither it nor a reader is needed.
"""

import io
import sys
import types
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

# Stand-in for pyserial, installed before the bridge is imported.
_serial = types.ModuleType("serial")
_serial.SerialException = type("SerialException", (Exception,), {})
_serial.Serial = None  # replaced per test
_tools = types.ModuleType("serial.tools")
_list_ports = types.ModuleType("serial.tools.list_ports")
_list_ports.comports = lambda: []
_tools.list_ports = _list_ports
_serial.tools = _tools
sys.modules.setdefault("serial", _serial)
sys.modules.setdefault("serial.tools", _tools)
sys.modules.setdefault("serial.tools.list_ports", _list_ports)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rfid_bridge  # noqa: E402

PREFIX = "http://localhost:5173/record/"


class BuildRecordUrlTest(unittest.TestCase):
    def test_normalises_the_uid(self):
        self.assertEqual(
            rfid_bridge.build_record_url(" 04a1b2c3 ", PREFIX, ""),
            "http://localhost:5173/record/04A1B2C3",
        )

    def test_adds_the_suffix(self):
        self.assertEqual(
            rfid_bridge.build_record_url("ABCD", "https://medrec.example/r/", "?source=rfid"),
            "https://medrec.example/r/ABCD?source=rfid",
        )

    def test_rejects_uids_that_could_change_the_url(self):
        for uid in ("", "04 A1", "../admin", "A/B", "A?x=1", "A#b", "A" * 65, "ÄBC"):
            with self.subTest(uid=uid), self.assertRaises(ValueError):
                rfid_bridge.build_record_url(uid, PREFIX, "")

    def test_rejects_prefixes_that_are_not_websites(self):
        for prefix in ("localhost:5173/record/", "file:///etc/passwd", "javascript:alert(1)//", "/record/"):
            with self.subTest(prefix=prefix), self.assertRaises(ValueError):
                rfid_bridge.build_record_url("ABCD", prefix, "")


class HandleLineTest(unittest.TestCase):
    def run_line(self, line, no_browser=False):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(rfid_bridge, "open_url") as open_url, redirect_stdout(out), redirect_stderr(err):
            rfid_bridge.handle_line(line, PREFIX, "", "brave", no_browser)
        return open_url, out.getvalue(), err.getvalue()

    def test_card_message_opens_the_record(self):
        open_url, out, _ = self.run_line("RFID_UID:04a1b2c3\r\n")
        open_url.assert_called_once_with("http://localhost:5173/record/04A1B2C3", "brave")
        self.assertIn("Card 04A1B2C3 detected", out)

    def test_no_browser_only_prints(self):
        open_url, out, _ = self.run_line("RFID_UID:04A1B2C3", no_browser=True)
        open_url.assert_not_called()
        self.assertIn("http://localhost:5173/record/04A1B2C3", out)

    def test_invalid_uid_is_ignored(self):
        open_url, _, err = self.run_line("RFID_UID:../../etc")
        open_url.assert_not_called()
        self.assertIn("Ignored invalid card message", err)

    def test_other_lines_are_logged_not_opened(self):
        for line in ("MEDREC_READER_READY", "boot: rst:0x1", "", "   "):
            with self.subTest(line=line):
                open_url, _, _ = self.run_line(line)
                open_url.assert_not_called()

    def test_browser_failure_is_reported_not_raised(self):
        out, err = io.StringIO(), io.StringIO()
        failing = mock.Mock(side_effect=RuntimeError("Brave Browser was not found."))
        with mock.patch.object(rfid_bridge, "open_url", failing), redirect_stdout(out), redirect_stderr(err):
            rfid_bridge.handle_line("RFID_UID:ABCD", PREFIX, "", "brave", False)
        self.assertIn("Could not open the record page", err.getvalue())


class MonitorTest(unittest.TestCase):
    def test_reads_lines_from_the_serial_port_until_stopped(self):
        lines = [b"MEDREC_READER_READY\r\n", b"", b"RFID_UID:04A1B2C3\r\n"]

        class FakeSerial:
            def __init__(self, port, baudrate, timeout):
                self.port, self.baudrate = port, baudrate

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

            def reset_input_buffer(self):
                pass

            def readline(self):
                if lines:
                    return lines.pop(0)
                raise KeyboardInterrupt  # what Ctrl+C does

        out = io.StringIO()
        with mock.patch.object(rfid_bridge.serial, "Serial", FakeSerial), \
                mock.patch.object(rfid_bridge.time, "sleep"), redirect_stdout(out):
            code = rfid_bridge.monitor("COM3", 115200, PREFIX, "", "brave", True)
        self.assertEqual(code, 0)
        self.assertIn("ESP32 RFID reader is ready.", out.getvalue())
        self.assertIn("Card 04A1B2C3 detected: http://localhost:5173/record/04A1B2C3", out.getvalue())

    def test_serial_errors_exit_with_1(self):
        def broken(*args, **kwargs):
            raise rfid_bridge.serial.SerialException("could not open port COM9")

        err = io.StringIO()
        with mock.patch.object(rfid_bridge.serial, "Serial", broken), redirect_stdout(io.StringIO()), redirect_stderr(err):
            self.assertEqual(rfid_bridge.monitor("COM9", 115200, PREFIX, "", "brave", True), 1)
        self.assertIn("could not open port COM9", err.getvalue())


class FindPortTest(unittest.TestCase):
    def test_picks_a_usb_serial_adapter(self):
        ports = [
            types.SimpleNamespace(device="COM1", description="Communications Port", manufacturer=None, hwid="ACPI"),
            types.SimpleNamespace(device="COM5", description="Silicon Labs CP210x USB to UART Bridge", manufacturer="Silicon Labs", hwid="USB VID:PID=10C4:EA60"),
        ]
        with mock.patch.object(rfid_bridge.list_ports, "comports", return_value=ports):
            self.assertEqual(rfid_bridge.find_esp32_port(), "COM5")

    def test_none_when_nothing_matches(self):
        ports = [types.SimpleNamespace(device="COM1", description="Communications Port", manufacturer=None, hwid="ACPI")]
        with mock.patch.object(rfid_bridge.list_ports, "comports", return_value=ports):
            self.assertIsNone(rfid_bridge.find_esp32_port())


if __name__ == "__main__":
    unittest.main()
