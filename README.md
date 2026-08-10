# Price Check &amp; Product Database

Scan a barcode, see the item's **name and price** on a big kiosk screen, and
build a **product database** you can export into your POS system later.

Runs two ways:

- **Host + tablets (POS style)** — one PC hosts a **shared database**; tablets
  and phones on the same Wi-Fi connect to it and all see the same products.
- **Standalone** — just open it in a browser; data stays in that browser.

No build step and no dependencies beyond Python (only needed for hosting).

## Why

Your POS is still being tested, but you need price checks **now**. This tool
lets you:

1. Scan a barcode and instantly see the product name and price.
2. Add products as you go, building a clean database.
3. Export that database (CSV or JSON) to import into the POS later.

## Quick start — host PC + tablet over Wi-Fi

On the **PC** that will hold the data:

1. Install [Python 3](https://www.python.org/downloads/) if you don't have it
   (tick **"Add Python to PATH"** during setup).
2. Run **`allow-firewall.bat`** once (approve the admin prompt) so tablets are
   allowed to connect.
3. Double-click **`host.bat`**. It prints two addresses:

   ```
   On this PC:        http://localhost:8000/
   On the tablet:     http://192.168.1.50:8000/     <-- use this one
   ```

On the **tablet**, connected to the same Wi-Fi:

4. Open the browser and type the **"On the tablet"** address.
5. Optional: use *Add to Home Screen* so it opens fullscreen like an app.

That's it. Add a product on the PC and the tablet sees it within a few
seconds — and vice versa. Everything is stored on the PC in `data.json`;
nothing leaves your network.

> **Both devices must be on the same Wi-Fi**, and the PC must stay on and
> running `host.bat` for tablets to work. If the tablet can't connect, check
> the firewall step and that Windows treats your Wi-Fi as a **Private**
> network.

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
- **Shared database over Wi-Fi** — when served by `host.bat`/`server.py`, every
  device reads and writes **one** database on the host PC and picks up other
  devices' changes within a few seconds. Products, currency, auto-clear delay
  and the Manage PIN are all shared.
- **Works offline-ish and standalone** — opened without the host (plain file or
  static hosting), it falls back to that browser's own `localStorage`. Either
  way nothing is sent to the internet.

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

### Starting and stopping the host

Double-click **`host.bat`** on the PC. Leave the window open — it *is* the
server. It restarts itself automatically if it stops. To shut down, press
**Ctrl+C** twice or close the window.

On macOS/Linux, or to run it by hand:

```bash
python3 server.py        # port 8000
python3 server.py 8080   # custom port
```

To change the port on Windows, edit `set "PORT=8000"` at the top of
`host.bat` (and re-run `allow-firewall.bat`, which opens port 8000).

## Files

| File                 | What it is                                          |
|----------------------|-----------------------------------------------------|
| `index.html`         | Page structure                                      |
| `styles.css`         | Styling (dark theme, responsive)                    |
| `app.js`             | Scanning, lookup, database, sync                    |
| `server.py`          | The host: shared database + serves the app          |
| `host.bat`           | Windows: run the host, with auto-restart            |
| `allow-firewall.bat` | Windows, one-time: let tablets reach this PC        |

## Where the data lives

With a host running, everything is in **`data.json`** next to `server.py` on the
host PC. Back that file up and you've backed up the shop. It is written
atomically, and a corrupt file is preserved as `data.json.corrupt` rather than
discarded. It's excluded from git so your real prices never get committed.

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

## Notes

- **The PC must be on** and running `host.bat` for tablets to work — it holds
  the database; the tablets are just screens.
- **Same Wi-Fi**, and Windows must treat that network as **Private** (the
  firewall rule deliberately does not cover public networks).
- **Back up `data.json`** on the host — that single file is your whole product
  database. **Export CSV/JSON** from the Manage panel also works as a backup and
  is what you'll feed into the POS later.
- Without a host (opening the files directly), each browser keeps its own
  separate list — fine for trying it out, but not for the shop.
