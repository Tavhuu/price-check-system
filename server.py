#!/usr/bin/env python3
"""
Price Check - host server.

Runs on the shop's PC (the "host"). Serves the app to any device on the same
Wi-Fi (tablets, phones, other PCs) and keeps ONE shared product database that
every device reads and writes - like a POS system.

    python server.py            # port 8000
    python server.py 8080       # custom port

Data lives in its own SQLite database, pricecheck.db, next to this file.
SQLite is used (rather than a plain JSON file) so a power cut cannot corrupt
the shop's data: every change is a transaction that either fully happens or
does not happen at all. Nothing leaves your network.

Endpoints used by the app:
    GET  /api/rev    -> {"rev": N}                 (cheap change check)
    GET  /api/data   -> {"rev": N, "products": [...], "settings": {...}}
    PUT  /api/data   -> save {"products": [...], "settings": {...}}
"""

import json
import os
import socket
import sqlite3
import sys
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(BASE_DIR, "pricecheck.db")
LEGACY_JSON = os.path.join(BASE_DIR, "data.json")
DEFAULT_PORT = 8000
MAX_BODY = 32 * 1024 * 1024  # cap so a bad request can't exhaust memory

PRODUCT_FIELDS = ("id", "barcode", "name", "price", "category", "sku",
                  "createdAt", "updatedAt")

_lock = threading.Lock()


def connect():
    """Open the database with settings chosen for power-loss safety."""
    conn = sqlite3.connect(DB_FILE, timeout=10)
    conn.row_factory = sqlite3.Row
    # WAL keeps readers fast while a write is in progress; FULL sync means a
    # committed change is really on disk before we report success.
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=FULL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    """Create tables if needed and import any old data.json exactly once."""
    fresh = not os.path.exists(DB_FILE)
    conn = connect()
    try:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS products (
                id        TEXT PRIMARY KEY,
                barcode   TEXT NOT NULL UNIQUE,
                name      TEXT NOT NULL,
                price     REAL NOT NULL DEFAULT 0,
                category  TEXT NOT NULL DEFAULT '',
                sku       TEXT NOT NULL DEFAULT '',
                createdAt TEXT NOT NULL DEFAULT '',
                updatedAt TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS meta (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            INSERT OR IGNORE INTO meta (key, value) VALUES ('rev', '0');
            """
        )
        conn.commit()

        if fresh and os.path.exists(LEGACY_JSON):
            migrated = _import_json(conn)
            if migrated is not None:
                print("  Imported %d products from the old data.json." % migrated)
    finally:
        conn.close()


def _import_json(conn):
    """One-time import of the previous data.json format."""
    try:
        with open(LEGACY_JSON, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        products = data.get("products") or []
        settings = data.get("settings") or {}
        _write(conn, products, settings)
        os.replace(LEGACY_JSON, LEGACY_JSON + ".imported")
        return len(products)
    except (OSError, json.JSONDecodeError, ValueError, sqlite3.Error) as exc:
        print("  ! Could not import data.json (%s); starting empty." % exc)
        return None


def _row_to_product(row):
    p = {k: row[k] for k in PRODUCT_FIELDS}
    p["price"] = float(p["price"] or 0)
    return p


def read_all():
    conn = connect()
    try:
        rev = int(conn.execute("SELECT value FROM meta WHERE key='rev'").fetchone()[0])
        products = [_row_to_product(r) for r in
                    conn.execute("SELECT * FROM products ORDER BY rowid")]
        settings = {r["key"]: json.loads(r["value"])
                    for r in conn.execute("SELECT * FROM settings")}
        return {"rev": rev, "products": products, "settings": settings}
    finally:
        conn.close()


def read_rev():
    conn = connect()
    try:
        return int(conn.execute("SELECT value FROM meta WHERE key='rev'").fetchone()[0])
    finally:
        conn.close()


def _write(conn, products, settings):
    """Replace the whole catalogue inside one transaction."""
    rows = []
    seen = set()
    for p in products:
        if not isinstance(p, dict):
            continue
        barcode = str(p.get("barcode", "")).strip()
        name = str(p.get("name", "")).strip()
        if not barcode or not name or barcode in seen:
            continue  # skip blanks and duplicate barcodes
        seen.add(barcode)
        try:
            price = float(p.get("price") or 0)
        except (TypeError, ValueError):
            price = 0.0
        rows.append((
            str(p.get("id") or barcode),
            barcode,
            name,
            price,
            str(p.get("category") or ""),
            str(p.get("sku") or ""),
            str(p.get("createdAt") or ""),
            str(p.get("updatedAt") or ""),
        ))

    with conn:  # commits on success, rolls back on any error
        conn.execute("DELETE FROM products")
        conn.executemany(
            "INSERT INTO products (id, barcode, name, price, category, sku,"
            " createdAt, updatedAt) VALUES (?,?,?,?,?,?,?,?)", rows)
        conn.execute("DELETE FROM settings")
        conn.executemany(
            "INSERT INTO settings (key, value) VALUES (?,?)",
            [(str(k), json.dumps(v)) for k, v in settings.items()])
        conn.execute(
            "UPDATE meta SET value = CAST(CAST(value AS INTEGER) + 1 AS TEXT)"
            " WHERE key='rev'")
    return len(rows)


def save_data(products, settings):
    with _lock:
        conn = connect()
        try:
            _write(conn, products, settings)
        finally:
            conn.close()
    return read_all()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

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

    def do_GET(self):
        if self.path == "/api/rev":
            self._send_json({"rev": read_rev()})
            return
        if self.path == "/api/data":
            self._send_json(read_all())
            return
        # Never hand out the database itself over HTTP.
        if os.path.basename(self.path.split("?")[0]).startswith("pricecheck.db"):
            self.send_error(404, "Not found")
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
        try:
            self._send_json(save_data(products, settings))
        except sqlite3.Error as exc:
            self.send_error(500, "Database error: %s" % exc)

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

    try:
        init_db()
        data = read_all()
    except sqlite3.Error as exc:
        print("\n  Could not open the database: %s" % exc)
        print("  File: %s\n" % DB_FILE)
        return 1

    try:
        httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    except OSError as exc:
        print("\n  Could not start on port %d: %s" % (port, exc))
        print("  Another program may already be using it. Try: python server.py 8080\n")
        return 1

    ips = lan_ips()
    print("")
    print("  Price Check host is running.")
    print("  Products in database: %d" % len(data["products"]))
    print("")
    print("  On this PC:        http://localhost:%d/" % port)
    for ip in ips:
        print("  On the tablet:     http://%s:%d/" % (ip, port))
    if not ips:
        print("  (Could not detect a network address - check your Wi-Fi connection.)")
    print("")
    print("  Type that address into the tablet's browser, on the same Wi-Fi.")
    print("  If it will not connect, run allow-firewall.bat once as administrator.")
    print("")
    print("  Database: %s" % DB_FILE)
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
