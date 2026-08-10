# Price Check &amp; Product Database

A simple, self-contained web app to **scan a barcode, check an item's name and
price**, and build a **product database** you can export and later import into
your POS system.

No build step, no server, no dependencies. Open it in a browser and start
scanning.

## Why

Your POS is still being tested, but you need price checks **now**. This tool
lets you:

1. Scan (or type) a barcode and instantly see the product name and price.
2. Add products as you go, building a clean database.
3. Export that database (CSV or JSON) to import into the POS later.

## Features

- **Supermarket-style kiosk screen** — a clean, minimal display that just says
  *"Scan a barcode"*. Scan an item and the name and a big price appear, then it
  **auto-clears back to idle after 5 seconds** (configurable) — ready for the
  next customer. No buttons to press between scans.
- **Auto-scan with a hardware barcode scanner** — plug in a USB or Bluetooth
  barcode scanner (the "keyboard wedge" kind) and just scan. Keystrokes are
  captured automatically; you never have to click into a field first. The
  scanner types the barcode and sends Enter, and the price appears instantly.
- **Fullscreen mode** — tap ⛶ (top-left) to fill the whole screen like a real
  price-check terminal; tap again to exit.
- **PIN-locked management** — protect the ⚙️ Manage panel with a PIN so
  customers can scan freely but only staff can change products or settings.
  A touch-friendly keypad is built in. Set, change, or remove the PIN inside
  Manage (with no PIN set, Manage opens freely so you can't get locked out).
- **Manage panel** — the product database and all settings live behind the ⚙️
  button, keeping the scan screen distraction-free.
- **Product database** — barcode, name, price, and optional category and SKU.
- **Search** across name, barcode, category and SKU.
- **Import CSV** — bulk-load an existing product list. Column names are matched
  flexibly (e.g. `upc`/`ean`/`code` → barcode, `retail`/`sell` → price).
  Existing barcodes are updated, new ones are added.
- **Export CSV / JSON** — take your database anywhere, including your POS.
- **Configurable currency symbol** (`$`, `€`, `£`, `₫`, `kr`, …).
- **Local persistence** — everything is saved in your browser's `localStorage`.
  Nothing is sent anywhere.

## Usage

Open `index.html` in a modern web browser. Scan an item with your hardware
scanner — the price shows and clears itself after a few seconds. Tap ⚙️
(top-right) to manage products, set your currency, or change the auto-clear
delay.

Most USB/Bluetooth barcode scanners work in "keyboard wedge" mode out of the
box and send an **Enter** after each barcode, which is exactly what this
expects — plug it in and scan.

**Fullscreen & PIN:** Tap ⛶ (top-left) for fullscreen. To stop customers
changing prices, open ⚙️ Manage → set a **Manage PIN**; after that the gear
asks for the PIN. Clear the field and press *Update PIN* to turn it off. The
PIN is stored only in this browser (hashed), as a deterrent — not bank-grade
security.

### Running it on a Windows PC

Double-click **`server.bat`**. It starts a local web server for this folder
and opens the price checker in your browser at `http://localhost:8000/`. Keep
the little black window open while you use the app; close it (or press Ctrl+C)
to stop. It uses Python if installed, otherwise PHP or Node; if none are found
it tells you to install Python from <https://www.python.org/downloads/> (tick
*"Add Python to PATH"* during setup).

**Friendly URL (optional):** if you'd rather open `http://pricecheck.local:8000/`
than `localhost`, run **`set-hostname.bat`** once (approve the administrator
prompt). It adds a single line to the Windows hosts file mapping
`pricecheck.local` to this PC. After that, `server.bat` opens the friendly URL
automatically; if the hostname isn't set up it just falls back to `localhost`.
To change the name, edit `HOSTNAME` at the top of both files. To undo, remove
the `pricecheck.local` line from `C:\Windows\System32\drivers\etc\hosts`.
(The `.local` name only works on this PC — it's a local alias, not a public
web address.)

### Always-on POS mode (Windows)

For a till/terminal that should just always be running, double-click
**`kiosk.bat`**. It behaves like a point-of-sale terminal:

- **Server auto-restart** — starts the local server and automatically
  restarts it if it ever stops.
- **Fullscreen** — opens the app in Chrome/Edge **kiosk mode** (true
  fullscreen, no tabs or address bar). Falls back to your default browser if
  neither is installed.
- **Browser auto-reopen** — if the fullscreen window is closed, it reopens
  after a couple of seconds.

**Start on login:** run **`install-startup.bat`** once (no admin needed) and the
kiosk launches automatically every time Windows logs in. Undo it with
**`uninstall-startup.bat`**.

**To stop the kiosk:** press **Alt+F4** to close the fullscreen browser, then
close the small minimized *"Price Check Server"* window.

### Serving it manually (any OS)

```bash
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Batch files at a glance (Windows)

| File                    | What it does                                             |
|-------------------------|----------------------------------------------------------|
| `server.bat`            | Start the server once and open the browser (simple use). |
| `kiosk.bat`             | POS mode: auto-restart server + fullscreen + auto-reopen.|
| `install-startup.bat`   | Make `kiosk.bat` launch automatically at login.          |
| `uninstall-startup.bat` | Remove the auto-start.                                    |
| `set-hostname.bat`      | One-time: enable `http://pricecheck.local:8000/`.        |

## Importing into your POS later

Use **Export CSV**. The file has these columns:

| Column     | Meaning                          |
|------------|----------------------------------|
| `barcode`  | The scanned barcode / UPC / EAN  |
| `name`     | Product name                     |
| `price`    | Selling price                    |
| `category` | Product category (optional)      |
| `sku`      | Stock code (optional)            |

Most POS systems accept a CSV like this directly, or let you map these columns
during import. Prefer structured data? Use **Export JSON**.

## CSV import format

The importer needs at least `barcode` and `name` columns. It also recognises
common aliases:

- barcode: `barcode`, `upc`, `ean`, `code`
- name: `name`, `product`, `product name`, `description`, `item`
- price: `price`, `sell`, `retail`, `unit price`
- category: `category`, `group`, `dept`
- sku: `sku`, `stock code`

Rows whose barcode already exists in the database are **updated**; new barcodes
are **added**.

## Files

| File         | Purpose                              |
|--------------|--------------------------------------|
| `index.html` | Page structure                       |
| `styles.css` | Styling (dark theme, responsive)     |
| `app.js`     | Scanning, lookup, database & storage |

## Notes

Data lives in the browser that created it. Clearing browser data or switching
browsers/devices will not carry products over — use **Export** to keep a copy or
move it to your POS.
