#!/usr/bin/env python3
import json
import os
import socket
import sys
import time

SOCKET = os.path.join(
    os.environ["XDG_RUNTIME_DIR"],
    "hypr",
    os.environ["HYPRLAND_INSTANCE_SIGNATURE"],
    ".socket.sock",
)
MONITOR_TTL = 2.0


def request(query):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET)
    sock.sendall(query.encode())
    chunks = []
    while True:
        chunk = sock.recv(65536)
        if not chunk:
            break
        chunks.append(chunk)
    sock.close()
    return b"".join(chunks)


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 0.12
    monitors = b"[]"
    refreshed = 0.0
    while True:
        started = time.monotonic()
        try:
            clients = request("j/clients").replace(b"\n", b"").replace(b"\r", b"")
            if started - refreshed >= MONITOR_TTL:
                monitors = request("j/monitors").replace(b"\n", b"").replace(b"\r", b"")
                refreshed = started
            cursor = b'{"x":-99999,"y":-99999}'
            try:
                parts = request("cursorpos").strip().split(b",")
                if len(parts) == 2:
                    cursor = b'{"x":' + parts[0].strip() + b',"y":' + parts[1].strip() + b"}"
            except Exception:
                pass
            line = (
                b'{"clients":' + clients + b',"monitors":' + monitors
                + b',"cursor":' + cursor + b"}\n"
            )
        except Exception as exc:
            line = json.dumps({"error": str(exc)}).encode() + b"\n"
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
            time.sleep(1.0)
            continue
        sys.stdout.buffer.write(line)
        sys.stdout.buffer.flush()
        time.sleep(max(0.0, interval - (time.monotonic() - started)))


main()
