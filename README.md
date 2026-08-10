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
seconds — and vice versa. Everything is stored on the PC in `pricecheck.db`;
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
- **Deals & comments** — give a product an offer like `2 for $9.00` and it
  appears as a big highlighted badge under the price when the item is scanned.
  An optional comment line (`while stocks last`, `fridge only`…) shows beneath
  it. Both are optional; products without them look exactly as before.
- **Product database** — barcode, name, price, and an optional category.
- **Search** across name, barcode, category, deal and comment.
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
box — plug it in and scan. A scan is accepted whether your scanner sends
**Enter**, **Tab**, or **no suffix at all**, and whether it types fast or
slowly, so no scanner configuration should be needed.

### Scanner beeps but nothing appears

The beep only means the scanner *read* the barcode — it doesn't prove the
digits reached the app. Work through these:

1. **Watch the bottom of the kiosk screen while scanning.** It briefly shows
   `Reading… 5` as characters arrive.
   - **You see it** → the digits are arriving. If the price still doesn't show,
     that barcode isn't in the database yet: open ⚙️ Manage and check the
     barcode matches *exactly* (no missing leading zero).
   - **You see nothing** → no keystrokes are reaching the browser; continue below.
2. **Open Notepad and scan.** If the barcode doesn't type itself there either,
   the problem is the scanner, not the app — it isn't in **keyboard / HID
   keyboard ("keyboard wedge")** mode. Most scanners have a setup barcode in
   their manual to switch to it (as opposed to *USB serial/COM* or *HID POS*).
3. **Close the ⚙️ Manage panel.** While it's open, keystrokes go to the form
   fields, which is deliberate so you can type product names.
4. **Tap the screen once** after the tablet has been idle, so the browser page
   has focus, then scan again.

**Fullscreen & PIN:** Tap ⛶ (top-left) for fullscreen. To stop customers
changing prices, open ⚙️ Manage → set a **Manage PIN**; after that the gear
asks for the PIN. Clear the field and press *Update PIN* to turn it off. With a
host running the PIN applies to **every device**, so setting it on the PC also
locks the tablets. It is stored hashed and is a deterrent against customers and
casual tampering — not bank-grade security.

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

### Surviving reboots and power cuts

Run **`install-autostart.bat`** once — just double-click it, **no administrator
needed**. It registers the host under your account's *Run* key, so it starts
every time you log in to Windows. Sign out and back in to test it.

Undo it any time with **`uninstall-autostart.bat`** (your database is left
alone; it also clears any older method). Once auto-start is on you don't need
`host.bat` for normal use — it's still handy for *seeing* the tablet address,
and it now tells you if the host is already running instead of starting a
second copy.

**Starting before anyone logs in** — optional, needs admin. `install-autostart.bat`
only runs after you sign in. If the shop PC boots to a login screen and nobody
signs in, use **`install-autostart-boot.bat`** instead: it registers a scheduled
task that runs at boot as the SYSTEM account, verifies it really came up, and
reports the cause if not. Two caveats:

- Python must be installed **for all users** — SYSTEM cannot use a "just for me"
  install. This is the most common reason it fails.
- Keep the folder somewhere plain like `C:\PriceCheck` rather than a
  OneDrive-synced Desktop, which SYSTEM may not be able to read.

Use one method or the other, not both, or two copies will fight over the port.
The installers clear each other automatically.

**⚠️ Making the PC power itself back on after an outage is a BIOS setting, not
something software can do.** When mains power returns, a PC that was off stays
off unless its firmware is told otherwise. To enable it:

1. Restart and press <kbd>Del</kbd> / <kbd>F2</kbd> / <kbd>F10</kbd> (varies by
   make) to enter **BIOS/UEFI setup**.
2. Find **"Restore on AC Power Loss"**, **"AC Power Recovery"**, **"After Power
   Failure"** or similar — usually under *Power Management* or *Advanced*.
3. Set it to **Power On** (sometimes called *Last State*), then save and exit.

For full unattended recovery you need that BIOS setting **plus** either
`install-autostart-boot.bat`, or `install-autostart.bat` together with Windows
**automatic sign-in**. A small UPS on the PC and router is worth considering too
— it rides out brief cuts and lets the PC shut down cleanly.

**Optional nightly restart:** `schedule-reboot.bat` makes the PC reboot itself
daily at 04:00 (edit the time inside, or run it again and press **R** to
remove). Useful for a machine that never gets turned off; skip it if the PC is
switched off nightly anyway.

## Files

| File                      | What it is                                       |
|---------------------------|--------------------------------------------------|
| `index.html`              | Page structure                                   |
| `styles.css`              | Styling (dark theme, responsive)                 |
| `app.js`                  | Scanning, lookup, database, sync                 |
| `server.py`               | The host: shared database + serves the app       |
| `host.bat`                | Windows: run the host, with auto-restart         |
| `allow-firewall.bat`      | Windows, one-time: let tablets reach this PC     |
| `install-autostart.bat`   | One-time: start the host at login (no admin)     |
| `install-autostart-boot.bat` | Optional: start before login (needs admin)    |
| `uninstall-autostart.bat` | Turn off auto-start (any method)                 |
| `autostart.ps1`           | Does the work for the "before login" option      |
| `schedule-reboot.bat`     | Optional: nightly PC restart                     |

## Where the data lives

The host keeps its own **SQLite database**, `pricecheck.db`, next to
`server.py`. Back up that one file and you've backed up the shop.

SQLite is used instead of a plain text file specifically because of power
cuts: every change is a transaction that either completes fully or not at all,
so an outage mid-save can't leave you with a half-written or corrupted
catalogue. The database is never served over HTTP, and it's excluded from git
so your real prices never get committed.

If you used an earlier version with `data.json`, it is imported automatically
the first time the new host starts and renamed to `data.json.imported`.

## Importing into your POS later

Use **Export CSV**. The file has these columns:

| Column     | Meaning                          |
|------------|----------------------------------|
| `barcode`  | The scanned barcode / UPC / EAN  |
| `name`     | Product name                     |
| `price`    | Selling price                    |
| `category` | Product category (optional)      |
| `deal`     | Offer text, e.g. 2 for $9.00 (optional) |
| `note`     | Comment shown under the deal (optional) |

Most POS systems accept a CSV like this directly, or let you map these columns
during import. Prefer structured data? Use **Export JSON**.

## CSV import format

The importer needs at least `barcode` and `name` columns. It also recognises
common aliases:

- barcode: `barcode`, `upc`, `ean`, `code`
- name: `name`, `product`, `product name`, `description`, `item`
- price: `price`, `sell`, `retail`, `unit price`
- category: `category`, `group`, `dept`
- deal: `deal`, `offer`, `promo`, `promotion`, `special`
- note: `note`, `comment`, `comments`, `remark`

Rows whose barcode already exists in the database are **updated**; new barcodes
are **added**.

## Notes

- **The PC must be on** and running `host.bat` for tablets to work — it holds
  the database; the tablets are just screens.
- **Same Wi-Fi**, and Windows must treat that network as **Private** (the
  firewall rule deliberately does not cover public networks).
- **Back up `pricecheck.db`** on the host — that single file is your whole product
  database. **Export CSV/JSON** from the Manage panel also works as a backup and
  is what you'll feed into the POS later.
- Without a host (opening the files directly), each browser keeps its own
  separate list — fine for trying it out, but not for the shop.
