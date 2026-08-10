#!/usr/bin/env python3
"""
Price Check - host server.

Runs on the shop's PC (the "host"). Serves the app to any device on the same
Wi-Fi (tablets, phones, other PCs) and keeps ONE shared product database that
every device reads and writes - like a POS system.

    python server.py            # port 8000
    python server.py 8080       # custom port

Data is stored next to this file in data.json. Nothing leaves your network.

Endpoints used by the app:
    GET  /api/rev    -> {"rev": N}                 (cheap change check)
    GET  /api/data   -> {"rev": N, "products": [...], "settings": {...}}
    PUT  /api/data   -> save {"products": [...], "settings": {...}}
"""

import json
import os
import socket
import sys
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, "data.json")
DEFAULT_PORT = 8000
MAX_BODY = 32 * 1024 * 1024  # 32 MB cap so a bad request can't exhaust memory

_lock = threading.Lock()


def _empty():
    return {"rev": 0, "products": [], "settings": {}}


def load_data():
    """Read data.json, tolerating a missing or corrupt file."""
    try:
        with open(DATA_FILE, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            return _empty()
        data.setdefault("rev", 0)
        data.setdefault("products", [])
        data.setdefault("settings", {})
        return data
    except FileNotFoundError:
        return _empty()
    except (json.JSONDecodeError, OSError):
        # Keep a copy of the unreadable file rather than silently dropping it.
        try:
            os.replace(DATA_FILE, DATA_FILE + ".corrupt")
            print("  ! data.json was unreadable; kept a copy as data.json.corrupt")
        except OSError:
            pass
        return _empty()


def save_data(products, settings):
    """Write data.json atomically and bump the revision counter."""
    with _lock:
        current = load_data()
        data = {
            "rev": int(current.get("rev", 0)) + 1,
            "products": products,
            "settings": settings,
        }
        tmp = DATA_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, DATA_FILE)  # atomic on Windows and POSIX
        return data


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

    # --- helpers ---------------------------------------------------------
    def _send_json(self, obj, status=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # Always serve fresh app files so tablets pick up updates immediately.
        if not self.path.startswith("/api/"):
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    # --- routes ----------------------------------------------------------
    def do_GET(self):
        if self.path == "/api/rev":
            self._send_json({"rev": load_data().get("rev", 0)})
            return
        if self.path == "/api/data":
            self._send_json(load_data())
            return
        super().do_GET()

    def do_PUT(self):
        if self.path != "/api/data":
            self.send_error(404, "Not found")
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            self.send_error(400, "Bad Content-Length")
            return
        if length <= 0 or length > MAX_BODY:
            self.send_error(400, "Bad request body size")
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            products = payload.get("products")
            settings = payload.get("settings", {})
            if not isinstance(products, list) or not isinstance(settings, dict):
                raise ValueError("bad shape")
        except (json.JSONDecodeError, UnicodeDecodeError, ValueError, AttributeError):
            self.send_error(400, "Invalid JSON payload")
            return
        self._send_json(save_data(products, settings))

    def do_POST(self):  # accept POST as an alias for PUT
        self.do_PUT()

    def log_message(self, fmt, *args):
        # Keep the console readable: only show problems, not every asset fetch.
        status = str(args[1]) if len(args) > 1 else ""
        if status.startswith(("4", "5")):
            sys.stderr.write("  %s\n" % (fmt % args))


def lan_ips():
    """Best-effort list of this machine's LAN addresses."""
    ips = []
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 80))  # no traffic sent; just picks the route
            ips.append(s.getsockname()[0])
        finally:
            s.close()
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ip = info[4][0]
            if not ip.startswith("127.") and ip not in ips:
                ips.append(ip)
    except socket.gaierror:
        pass
    return ips


def main():
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("Usage: python server.py [port]")
            return 2

    data = load_data()
    try:
        httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    except OSError as exc:
        print("\n  Could not start on port %d: %s" % (port, exc))
        print("  Another program may already be using it. Try: python server.py 8080\n")
        return 1

    ips = lan_ips()
    print("")
    print("  Price Check host is running.")
    print("  Products in database: %d" % len(data.get("products", [])))
    print("")
    print("  On this PC:        http://localhost:%d/" % port)
    for ip in ips:
        print("  On the tablet:     http://%s:%d/" % (ip, port))
    if not ips:
        print("  (Could not detect a network address - check your Wi-Fi connection.)")
    print("")
    print("  Type that address into the tablet's browser, on the same Wi-Fi.")
    print("  If it will not connect, allow Python through the Windows firewall")
    print("  (or run allow-firewall.bat once as administrator).")
    print("")
    print("  Data file: %s" % DATA_FILE)
    print("  Press Ctrl+C to stop.")
    print("")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n  Stopped.")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
