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
FAST_INTERVAL = 0.016
FAST_WINDOW = 0.35
# Read-only lookup of the folder an opencode session is working in, so a strip
# can show the project / client name (e.g. "Buhle Projects") next to the title.
OPENCODE_DB = os.path.expanduser("~/.local/share/opencode/opencode.db")
NAME_TTL = 60.0
_name_cache = {}

def session_name(title):
    st = title[5:] if title.startswith("OC | ") else title
    now = time.monotonic()
    hit = _name_cache.get(st)
    if hit is not None and now - hit[0] < NAME_TTL:
        return hit[1]
    name = ""
    try:
        import sqlite3
        if os.path.exists(OPENCODE_DB):
            conn = sqlite3.connect(
                "file:%s?mode=ro" % OPENCODE_DB, uri=True, timeout=1.0
            )
            try:
                row = conn.execute(
                    "SELECT directory FROM session WHERE title = ? "
                    "ORDER BY time_updated DESC LIMIT 1",
                    (st,),
                ).fetchone()
                # Hyprland truncates long titles with "…": fall back to a
                # prefix match so the name still resolves.
                if row is None or not row[0]:
                    short = st.rstrip("\u2026").rstrip()
                    if short and short != st:
                        row = conn.execute(
                            "SELECT directory FROM session WHERE title LIKE ? "
                            "AND title != ? ORDER BY time_updated DESC LIMIT 1",
                            (short + "%", st),
                        ).fetchone()
                if row and row[0]:
                    name = os.path.basename(os.path.normpath(row[0]))
            finally:
                conn.close()
    except Exception:
        name = ""
    _name_cache[st] = (now, name)
    return name

def annotate_names(clients):
    for client in clients:
        if client.get("class") == "org.omarchy.agent":
            client["name"] = session_name(client.get("title") or "")


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


def geometry_of(clients):
    return tuple(sorted(
        (
            client.get("address"),
            tuple(client.get("at") or ()),
            tuple(client.get("size") or ()),
            client.get("title"),
        )
        for client in clients
    ))


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 0.12
    monitors = b"[]"
    refreshed = 0.0
    previous = None
    fast_until = 0.0
    while True:
        started = time.monotonic()
        try:
            clients = json.loads(request("j/clients"))
            annotate_names(clients)
            if started - refreshed >= MONITOR_TTL:
                monitors = json.dumps(
                    json.loads(request("j/monitors")), separators=(",", ":")
                ).encode()
                refreshed = started
            geometry = geometry_of(clients)
            if previous is not None and geometry != previous:
                fast_until = started + FAST_WINDOW
            previous = geometry
            line = (
                b'{"clients":'
                + json.dumps(clients, separators=(",", ":")).encode()
                + b',"monitors":' + monitors + b"}\n"
            )
        except Exception as exc:
            line = json.dumps({"error": str(exc)}).encode() + b"\n"
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
            time.sleep(1.0)
            continue
        sys.stdout.buffer.write(line)
        sys.stdout.buffer.flush()
        pace = FAST_INTERVAL if time.monotonic() < fast_until else interval
        time.sleep(max(0.0, pace - (time.monotonic() - started)))


main()
