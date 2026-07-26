/* Price Check — supermarket-style kiosk
 * Self-contained: no build step, no server, no dependencies.
 *
 * Scanning:
 *   - Hardware barcode scanner (USB/Bluetooth "keyboard wedge"): captured
 *     globally — just scan, no need to click anything. The scanner types the
 *     digits fast and sends Enter; we look up the price instantly.
 *   - Manual entry and phone camera (native BarcodeDetector) also supported.
 *
 * After a result is shown it auto-clears back to "Scan a barcode" after a
 * configurable delay (default 5 seconds).
 *
 * Data lives in localStorage.
 */

(function () {
  "use strict";

  var STORAGE_KEY = "priceCheck.products.v1";
  var CURRENCY_KEY = "priceCheck.currency.v1";
  var AUTOCLEAR_KEY = "priceCheck.autoClearSec.v1";

  /* ---------- State ---------- */
  var products = load();
  var editingId = null;
  var currency = localStorage.getItem(CURRENCY_KEY) || "$";
  var autoClearSec = clampInt(localStorage.getItem(AUTOCLEAR_KEY), 1, 60, 5);
  var lastScan = "";
  var clearTimer = null;

  /* ---------- Elements ---------- */
  var $ = function (id) { return document.getElementById(id); };
  var els = {
    // kiosk
    openManage: $("openManage"),
    stateIdle: $("stateIdle"),
    stateFound: $("stateFound"),
    stateNotFound: $("stateNotFound"),
    foundName: $("foundName"),
    foundPrice: $("foundPrice"),
    foundMeta: $("foundMeta"),
    notFoundCode: $("notFoundCode"),
    countdownBar: $("countdownBar"),
    countdownBar2: $("countdownBar2"),
    manualForm: $("manualForm"),
    manualInput: $("manualInput"),
    cameraToggle: $("cameraToggle"),
    cameraWrap: $("cameraWrap"),
    cameraClose: $("cameraClose"),
    video: $("video"),
    kioskStatus: $("kioskStatus"),

    // manage
    manageOverlay: $("manageOverlay"),
    managePanel: $("managePanel"),
    closeManage: $("closeManage"),
    sumCount: $("sumCount"),
    sumAvg: $("sumAvg"),
    sumLast: $("sumLast"),
    currency: $("currency"),
    autoClear: $("autoClear"),
    productForm: $("productForm"),
    formTitle: $("formTitle"),
    productId: $("productId"),
    fBarcode: $("fBarcode"),
    fName: $("fName"),
    fPrice: $("fPrice"),
    fCost: $("fCost"),
    fCategory: $("fCategory"),
    fSku: $("fSku"),
    saveBtn: $("saveBtn"),
    cancelEditBtn: $("cancelEditBtn"),
    search: $("search"),
    importBtn: $("importBtn"),
    importFile: $("importFile"),
    exportCsvBtn: $("exportCsvBtn"),
    exportJsonBtn: $("exportJsonBtn"),
    tableBody: $("tableBody"),
    emptyMsg: $("emptyMsg"),
    dbCount: $("dbCount"),
  };

  /* ---------- Persistence ---------- */
  function load() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch (e) { return []; }
  }
  function save() { localStorage.setItem(STORAGE_KEY, JSON.stringify(products)); }

  /* ---------- Helpers ---------- */
  function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 7); }
  function normBarcode(b) { return String(b == null ? "" : b).trim(); }
  function findByBarcode(b) {
    var key = normBarcode(b);
    for (var i = 0; i < products.length; i++) {
      if (normBarcode(products[i].barcode) === key) return products[i];
    }
    return null;
  }
  function money(n) {
    var v = Number(n);
    if (!isFinite(v)) v = 0;
    return currency + v.toFixed(2);
  }
  function clampInt(v, min, max, dflt) {
    var n = parseInt(v, 10);
    if (!isFinite(n)) return dflt;
    return Math.max(min, Math.min(max, n));
  }
  function escapeHtml(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;")
      .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  function isManageOpen() { return !els.managePanel.hidden; }

  var toastTimer = null;
  function toast(msg, kind) {
    var t = document.querySelector(".toast");
    if (!t) { t = document.createElement("div"); t.className = "toast"; document.body.appendChild(t); }
    t.textContent = msg;
    t.className = "toast show" + (kind ? " " + kind : "");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.className = "toast" + (kind ? " " + kind : ""); }, 2400);
  }

  /* ================= KIOSK DISPLAY ================= */
  function showState(which) {
    els.stateIdle.hidden = which !== "idle";
    els.stateFound.hidden = which !== "found";
    els.stateNotFound.hidden = which !== "notfound";
  }

  function runCountdown(bar) {
    if (!bar) return;
    bar.classList.remove("run");
    // Force reflow so the animation restarts each scan.
    void bar.offsetWidth;
    bar.style.animationDuration = autoClearSec + "s";
    bar.classList.add("run");
  }

  function showIdle() {
    clearTimeout(clearTimer);
    clearTimer = null;
    showState("idle");
  }

  function armAutoClear() {
    clearTimeout(clearTimer);
    clearTimer = setTimeout(showIdle, autoClearSec * 1000);
  }

  function doLookup(barcode) {
    var b = normBarcode(barcode);
    if (!b) return;
    lastScan = b;

    var p = findByBarcode(b);
    if (p) {
      els.foundName.textContent = p.name;
      els.foundPrice.textContent = money(p.price);
      els.foundMeta.textContent = p.barcode + (p.category ? "  ·  " + p.category : "");
      showState("found");
      runCountdown(els.countdownBar);
      if (navigator.vibrate) navigator.vibrate(50);
    } else {
      els.notFoundCode.textContent = b;
      showState("notfound");
      runCountdown(els.countdownBar2);
      if (navigator.vibrate) navigator.vibrate([40, 60, 40]);
    }
    armAutoClear();
    renderSummary();
  }

  /* ================= HARDWARE SCANNER (keyboard wedge) ================= */
  // A barcode scanner behaves like a keyboard: it types the code very fast and
  // ends with Enter. We buffer keystrokes globally and submit on Enter, so the
  // user never has to focus a field. A pause resets the buffer, so stray key
  // presses don't accumulate into a bogus code.
  var scanBuffer = "";
  var lastKeyAt = 0;
  var INTERKEY_RESET_MS = 200; // gap larger than this starts a fresh buffer

  document.addEventListener("keydown", function (e) {
    // Let real typing into any field (manage panel, manual box) behave normally.
    var tag = (e.target && e.target.tagName ? e.target.tagName : "").toUpperCase();
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
    if (e.ctrlKey || e.metaKey || e.altKey) return;

    var now = Date.now();
    if (now - lastKeyAt > INTERKEY_RESET_MS) scanBuffer = "";
    lastKeyAt = now;

    if (e.key === "Enter") {
      if (scanBuffer.length >= 3) doLookup(scanBuffer);
      scanBuffer = "";
      return;
    }
    // Accept typical barcode characters only.
    if (e.key.length === 1 && /[0-9A-Za-z\-]/.test(e.key)) {
      scanBuffer += e.key;
    }
  });

  /* ================= MANUAL + CAMERA ================= */
  els.manualForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var v = els.manualInput.value;
    els.manualInput.value = "";
    doLookup(v);
  });

  var scanner = { stream: null, detector: null, running: false, rafId: null };
  function scanSupported() { return "BarcodeDetector" in window; }

  async function openCamera() {
    if (!scanSupported()) {
      els.kioskStatus.textContent = "Camera scanning isn't supported here — use the barcode field or a hardware scanner.";
      return;
    }
    if (scanner.running) return;
    try {
      els.kioskStatus.textContent = "Starting camera…";
      scanner.detector = new window.BarcodeDetector({
        formats: ["ean_13", "ean_8", "upc_a", "upc_e", "code_128", "code_39", "itf", "codabar"],
      });
      scanner.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false });
      els.video.srcObject = scanner.stream;
      await els.video.play();
      els.cameraWrap.hidden = false;
      scanner.running = true;
      els.kioskStatus.textContent = "Point the camera at a barcode…";
      scanLoop();
    } catch (e) {
      els.kioskStatus.textContent = "Couldn't access the camera. Check permissions or use the barcode field.";
      closeCamera();
    }
  }

  var lastDetected = { code: "", at: 0 };
  async function scanLoop() {
    if (!scanner.running) return;
    try {
      var codes = await scanner.detector.detect(els.video);
      if (codes && codes.length) {
        var value = normBarcode(codes[0].rawValue);
        var now = Date.now();
        if (value && !(value === lastDetected.code && now - lastDetected.at < 2500)) {
          lastDetected = { code: value, at: now };
          doLookup(value);
        }
      }
    } catch (e) { /* transient detect errors are fine */ }
    scanner.rafId = requestAnimationFrame(scanLoop);
  }

  function closeCamera() {
    scanner.running = false;
    if (scanner.rafId) cancelAnimationFrame(scanner.rafId);
    if (scanner.stream) { scanner.stream.getTracks().forEach(function (t) { t.stop(); }); scanner.stream = null; }
    els.video.srcObject = null;
    els.cameraWrap.hidden = true;
    els.kioskStatus.textContent = "";
  }

  els.cameraToggle.addEventListener("click", function () {
    if (scanner.running) closeCamera(); else openCamera();
  });
  els.cameraClose.addEventListener("click", closeCamera);

  /* ================= MANAGE PANEL ================= */
  function openManage() {
    els.manageOverlay.hidden = false;
    els.managePanel.hidden = false;
    renderAll();
  }
  function closeManage() {
    els.manageOverlay.hidden = true;
    els.managePanel.hidden = true;
    resetForm();
  }
  els.openManage.addEventListener("click", openManage);
  els.closeManage.addEventListener("click", closeManage);
  els.manageOverlay.addEventListener("click", closeManage);
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && isManageOpen()) closeManage();
  });

  /* ---------- Summary + table ---------- */
  function renderSummary() {
    els.sumCount.textContent = String(products.length);
    var sum = 0, n = 0;
    for (var i = 0; i < products.length; i++) {
      var p = Number(products[i].price);
      if (isFinite(p)) { sum += p; n++; }
    }
    els.sumAvg.textContent = n ? money(sum / n) : money(0);
    els.sumLast.textContent = lastScan || "—";
  }

  function renderTable() {
    var q = els.search.value.trim().toLowerCase();
    var rows = products.filter(function (p) {
      if (!q) return true;
      return (
        String(p.name || "").toLowerCase().indexOf(q) !== -1 ||
        String(p.barcode || "").toLowerCase().indexOf(q) !== -1 ||
        String(p.category || "").toLowerCase().indexOf(q) !== -1 ||
        String(p.sku || "").toLowerCase().indexOf(q) !== -1
      );
    });

    els.tableBody.innerHTML = "";
    els.dbCount.textContent =
      products.length + " product" + (products.length === 1 ? "" : "s") +
      (q && rows.length !== products.length ? " · " + rows.length + " shown" : "");

    if (!products.length) {
      els.emptyMsg.hidden = false;
      els.emptyMsg.textContent = "No products yet. Add one above or import a CSV.";
      return;
    }
    if (!rows.length) {
      els.emptyMsg.hidden = false;
      els.emptyMsg.textContent = "No products match your search.";
      return;
    }
    els.emptyMsg.hidden = true;

    var frag = document.createDocumentFragment();
    rows.forEach(function (p) {
      var tr = document.createElement("tr");
      var price = Number(p.price);
      var cost = p.cost === "" || p.cost == null ? null : Number(p.cost);
      var marginHtml = "—";
      if (cost != null && isFinite(cost) && isFinite(price)) {
        var m = price - cost;
        marginHtml = '<span class="' + (m >= 0 ? "margin-pos" : "margin-neg") + '">' + money(m) + "</span>";
      }
      tr.innerHTML =
        '<td class="barcode-cell">' + escapeHtml(p.barcode) + "</td>" +
        "<td>" + escapeHtml(p.name) + "</td>" +
        "<td>" + escapeHtml(p.category || "") + "</td>" +
        '<td class="num">' + money(price) + "</td>" +
        '<td class="num">' + (cost != null && isFinite(cost) ? money(cost) : "—") + "</td>" +
        '<td class="num">' + marginHtml + "</td>" +
        '<td class="actions-col">' +
          '<button class="row-btn edit" data-id="' + p.id + '">Edit</button>' +
          '<button class="row-btn del" data-id="' + p.id + '">Delete</button>' +
        "</td>";
      frag.appendChild(tr);
    });
    els.tableBody.appendChild(frag);
  }

  function renderAll() { renderSummary(); renderTable(); }

  /* ---------- Add / edit ---------- */
  function startEdit(id) {
    var p = null;
    for (var i = 0; i < products.length; i++) if (products[i].id === id) p = products[i];
    if (!p) return;
    editingId = id;
    els.productId.value = id;
    els.fBarcode.value = p.barcode || "";
    els.fName.value = p.name || "";
    els.fPrice.value = p.price != null ? p.price : "";
    els.fCost.value = p.cost != null ? p.cost : "";
    els.fCategory.value = p.category || "";
    els.fSku.value = p.sku || "";
    els.formTitle.textContent = "Edit Product";
    els.saveBtn.textContent = "Update Product";
    els.cancelEditBtn.hidden = false;
    els.fName.focus();
  }

  function resetForm() {
    editingId = null;
    els.productForm.reset();
    els.productId.value = "";
    els.formTitle.textContent = "Add Product";
    els.saveBtn.textContent = "Save Product";
    els.cancelEditBtn.hidden = true;
  }

  function saveProduct(e) {
    e.preventDefault();
    var barcode = normBarcode(els.fBarcode.value);
    var name = els.fName.value.trim();
    var price = els.fPrice.value;
    if (!barcode || !name || price === "") {
      toast("Barcode, name and price are required.", "error");
      return;
    }
    var dup = findByBarcode(barcode);
    if (dup && dup.id !== editingId) {
      toast("That barcode already exists — editing it instead.", "error");
      startEdit(dup.id);
      return;
    }
    var data = {
      barcode: barcode,
      name: name,
      price: Number(price),
      cost: els.fCost.value === "" ? "" : Number(els.fCost.value),
      category: els.fCategory.value.trim(),
      sku: els.fSku.value.trim(),
    };
    if (editingId) {
      for (var i = 0; i < products.length; i++) {
        if (products[i].id === editingId) {
          products[i] = Object.assign(products[i], data);
          products[i].updatedAt = new Date().toISOString();
        }
      }
      toast("Product updated.", "success");
    } else {
      data.id = uid();
      data.createdAt = new Date().toISOString();
      products.push(data);
      toast("Product added.", "success");
    }
    save();
    resetForm();
    renderAll();
  }

  function deleteProduct(id) {
    var p = null;
    for (var i = 0; i < products.length; i++) if (products[i].id === id) p = products[i];
    if (!p) return;
    if (!confirm('Delete "' + p.name + '"?')) return;
    products = products.filter(function (x) { return x.id !== id; });
    save();
    if (editingId === id) resetForm();
    renderAll();
    toast("Product deleted.");
  }

  els.productForm.addEventListener("submit", saveProduct);
  els.cancelEditBtn.addEventListener("click", resetForm);
  els.tableBody.addEventListener("click", function (e) {
    var btn = e.target.closest("button");
    if (!btn) return;
    var id = btn.getAttribute("data-id");
    if (btn.classList.contains("edit")) startEdit(id);
    else if (btn.classList.contains("del")) deleteProduct(id);
  });
  els.search.addEventListener("input", renderTable);

  els.currency.addEventListener("input", function () {
    currency = els.currency.value || "$";
    localStorage.setItem(CURRENCY_KEY, currency);
    renderAll();
  });
  els.autoClear.addEventListener("input", function () {
    autoClearSec = clampInt(els.autoClear.value, 1, 60, 5);
    localStorage.setItem(AUTOCLEAR_KEY, String(autoClearSec));
  });

  /* ---------- CSV import / export ---------- */
  var CSV_HEADERS = ["barcode", "name", "price", "cost", "category", "sku"];
  function csvEscape(v) {
    var s = String(v == null ? "" : v);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }
  function exportCsv() {
    if (!products.length) { toast("Nothing to export yet.", "error"); return; }
    var lines = [CSV_HEADERS.join(",")];
    products.forEach(function (p) {
      lines.push(CSV_HEADERS.map(function (h) { return csvEscape(p[h]); }).join(","));
    });
    downloadFile(lines.join("\r\n"), "products.csv", "text/csv");
    toast("Exported " + products.length + " products to CSV.", "success");
  }
  function exportJson() {
    if (!products.length) { toast("Nothing to export yet.", "error"); return; }
    downloadFile(JSON.stringify(products, null, 2), "products.json", "application/json");
    toast("Exported " + products.length + " products to JSON.", "success");
  }
  function downloadFile(content, filename, type) {
    var blob = new Blob([content], { type: type + ";charset=utf-8" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url; a.download = filename;
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }
  function parseCsv(text) {
    var rows = [], row = [], field = "", inQuotes = false;
    text = text.replace(/^﻿/, "");
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (inQuotes) {
        if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else inQuotes = false; }
        else field += c;
      } else {
        if (c === '"') inQuotes = true;
        else if (c === ",") { row.push(field); field = ""; }
        else if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; }
        else if (c === "\r") { /* skip */ }
        else field += c;
      }
    }
    if (field.length || row.length) { row.push(field); rows.push(row); }
    return rows;
  }
  function firstIndex(header, names) {
    for (var i = 0; i < names.length; i++) {
      var idx = header.indexOf(names[i]);
      if (idx !== -1) return idx;
    }
    return -1;
  }
  function cleanNumber(v) {
    var n = parseFloat(String(v == null ? "" : v).replace(/[^0-9.\-]/g, ""));
    return isFinite(n) ? n : 0;
  }
  function importCsv(file) {
    var reader = new FileReader();
    reader.onload = function () {
      try {
        var rows = parseCsv(String(reader.result)).filter(function (r) {
          return r.some(function (c) { return String(c).trim() !== ""; });
        });
        if (!rows.length) { toast("CSV appears to be empty.", "error"); return; }
        var header = rows[0].map(function (h) { return h.trim().toLowerCase(); });
        var idx = {};
        idx.barcode = firstIndex(header, ["barcode", "upc", "ean", "code"]);
        idx.name = firstIndex(header, ["name", "product", "product name", "description", "item"]);
        idx.price = firstIndex(header, ["price", "sell", "retail", "unit price"]);
        idx.cost = firstIndex(header, ["cost", "buy", "wholesale"]);
        idx.category = firstIndex(header, ["category", "group", "dept"]);
        idx.sku = firstIndex(header, ["sku", "stock code"]);
        if (idx.barcode < 0 || idx.name < 0) {
          toast("CSV needs at least 'barcode' and 'name' columns.", "error");
          return;
        }
        var added = 0, updated = 0, skipped = 0;
        for (var r = 1; r < rows.length; r++) {
          var cells = rows[r];
          var barcode = normBarcode(cells[idx.barcode]);
          var name = String(cells[idx.name] || "").trim();
          if (!barcode || !name) { skipped++; continue; }
          var costRaw = idx.cost >= 0 ? cells[idx.cost] : "";
          var rec = {
            barcode: barcode,
            name: name,
            price: idx.price >= 0 ? cleanNumber(cells[idx.price]) : 0,
            cost: costRaw === "" || costRaw == null ? "" : cleanNumber(costRaw),
            category: idx.category >= 0 ? String(cells[idx.category] || "").trim() : "",
            sku: idx.sku >= 0 ? String(cells[idx.sku] || "").trim() : "",
          };
          var existing = findByBarcode(barcode);
          if (existing) {
            Object.assign(existing, rec);
            existing.updatedAt = new Date().toISOString();
            updated++;
          } else {
            rec.id = uid();
            rec.createdAt = new Date().toISOString();
            products.push(rec);
            added++;
          }
        }
        save();
        renderAll();
        toast("Import done: " + added + " added, " + updated + " updated" +
          (skipped ? ", " + skipped + " skipped" : "") + ".", "success");
      } catch (e) {
        toast("Could not read that CSV file.", "error");
      }
    };
    reader.onerror = function () { toast("Could not read that file.", "error"); };
    reader.readAsText(file);
  }

  els.exportCsvBtn.addEventListener("click", exportCsv);
  els.exportJsonBtn.addEventListener("click", exportJson);
  els.importBtn.addEventListener("click", function () { els.importFile.click(); });
  els.importFile.addEventListener("change", function (e) {
    var file = e.target.files && e.target.files[0];
    if (file) importCsv(file);
    els.importFile.value = "";
  });

  window.addEventListener("beforeunload", closeCamera);

  /* ---------- Init ---------- */
  els.currency.value = currency;
  els.autoClear.value = String(autoClearSec);
  showIdle();
  renderAll();
})();
