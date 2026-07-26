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

- **Barcode scanning** — uses your device camera via the browser's native
  `BarcodeDetector` API (works great on Android Chrome and other modern
  browsers). Supports EAN-13/8, UPC-A/E, Code 128, Code 39, ITF and Codabar.
- **Manual entry fallback** — no camera or unsupported browser? Just type the
  barcode. Handy with a USB barcode scanner too (they type like a keyboard).
- **Instant price check** — shows the product name, category and price in a
  clear result card. Unknown barcodes get a one-tap "Add this product" prompt.
- **Product database** — barcode, name, price, optional cost, category and
  SKU. Auto-calculated **margin** (price − cost).
- **Search** across name, barcode, category and SKU.
- **Import CSV** — bulk-load an existing product list. Column names are matched
  flexibly (e.g. `upc`/`ean`/`code` → barcode, `retail`/`sell` → price).
  Existing barcodes are updated, new ones are added.
- **Export CSV / JSON** — take your database anywhere, including your POS.
- **Configurable currency symbol** (`$`, `€`, `£`, `₫`, `kr`, …).
- **Local persistence** — everything is saved in your browser's `localStorage`.
  Nothing is sent anywhere.

## Usage

Open `index.html` in a modern web browser. That's it.

> **Camera note:** Browsers only allow camera access over **HTTPS** or on
> `localhost`. If you open the file directly (`file://`), camera scanning may be
> blocked by the browser — serve it locally (below) or host it over HTTPS, or
> just use manual / USB-scanner entry.

To serve it locally (recommended for camera use):

```bash
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Importing into your POS later

Use **Export CSV**. The file has these columns:

| Column     | Meaning                          |
|------------|----------------------------------|
| `barcode`  | The scanned barcode / UPC / EAN  |
| `name`     | Product name                     |
| `price`    | Selling price                    |
| `cost`     | Cost price (optional)            |
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
- cost: `cost`, `buy`, `wholesale`
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
