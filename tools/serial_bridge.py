#!/usr/bin/env python3
"""Bidirectional UART bridge for tmux: serial <-> stdin, with optional log."""

import os
import select
import sys
import termios
import tty

import serial


def main() -> int:
    port = os.environ.get("SERIAL_PORT", "/dev/ttyUSB0")
    baud = int(os.environ.get("SERIAL_BAUD", "115200"))
    log_path = os.environ.get("SERIAL_LOG", "")

    ser = serial.Serial(port, baud, timeout=0)
    log_file = open(log_path, "ab", buffering=0) if log_path else None

    stdin_fd = sys.stdin.fileno()
    old_attrs = None
    if os.isatty(stdin_fd):
        old_attrs = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)

    try:
        while True:
            readable, _, _ = select.select([ser.fileno(), stdin_fd], [], [], 1.0)
            if ser.fileno() in readable:
                data = ser.read(4096)
                if data:
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
                    if log_file:
                        log_file.write(data)
            if stdin_fd in readable:
                data = os.read(stdin_fd, 4096)
                if not data:
                    break
                ser.write(data)
                ser.flush()
    except KeyboardInterrupt:
        pass
    finally:
        if old_attrs is not None:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_attrs)
        ser.close()
        if log_file:
            log_file.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
