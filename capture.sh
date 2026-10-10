#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p bash -c '
set -euo pipefail
url="${CAPTURE_URL:?Set CAPTURE_URL.}"
out="${CAPTURE_DIR:?Set CAPTURE_DIR.}"
mkdir -p "$out"
runtime_home="$HOME/.local/share/omgithub-playwright"
export DISPLAY="${DISPLAY:-:$(cat "$runtime_home/display" 2>/dev/null || echo 0)}"
node - "$url" "$out" <<'"'"'NODE'"'"'
const { readFileSync, mkdirSync, statSync } = require("fs");
const { join } = require("path");
const { createRequire } = require("module");
const runtime = join(process.env.HOME, ".local/share/omgithub-playwright");
const req = createRequire(join(runtime, "package.json"));
const { chromium } = req("playwright");
let config = { browser: { launchOptions: {} } };
try { config = JSON.parse(readFileSync(join(runtime, "linux.json"), "utf8")); } catch {}
const url = process.argv[2], output = process.argv[3];
mkdirSync(output, { recursive: true });
const transient = (err) => { console.error("TRANSIENT:", err && err.message || err); process.exit(75); };
const fatal = (err) => { console.error("FATAL:", err && err.stack || err); process.exit(1); };
(async () => {
  let browser;
  try {
    browser = await chromium.launch({ ...(config.browser.launchOptions || {}), timeout: 30000 }).catch(transient);
  } catch (e) { transient(e); }
  const shots = [["desktop", 1440, 900], ["mobile", 390, 844]];
  try {
    for (const [name, w, h] of shots) {
      const page = await browser.newPage({ viewport: { width: w, height: h } }).catch(transient);
      page.setDefaultTimeout(30000);
      let response;
      try {
        response = await page.goto(url, { waitUntil: "load", timeout: 45000 });
      } catch (e) { await page.close().catch(()=>{}); transient(e); }
      if (!response || !response.ok()) {
        const s = response ? response.status() : 0;
        await page.close().catch(()=>{});
        const e = new Error("HTTP " + s + " loading preview");
        if (!response || [408, 429, 500, 502, 503, 504].includes(s)) transient(e); else fatal(e);
      }
      try {
        await page.locator("body").waitFor({ state: "visible", timeout: 15000 });
        await page.waitForFunction(() => document.fonts ? document.fonts.status === "loaded" : true, null, { timeout: 15000 }).catch(()=>{});
        // Start the game if its entry button is present (do not follow links).
        const started = await page.evaluate(() => {
          const b = document.querySelector("#play");
          if (b && b.offsetParent !== null) { b.click(); return "clicked-#play"; }
          return "no-button";
        });
        console.log("Capture " + name + ": " + started);
        // Let WebGL2 ray-marcher render several frames.
        await page.waitForTimeout(name === "desktop" ? 6000 : 4000);
        const hasCanvas = await page.evaluate(() => !!document.querySelector("canvas#gl"));
        if (!hasCanvas) { await page.close().catch(()=>{}); fatal(new Error("rendering defect: missing canvas#gl")); }
      } catch (e) { if (e && e.message && e.message.startsWith("rendering defect")) fatal(e); else transient(e); }
      try {
        await page.screenshot({ path: join(output, "final-" + name + ".png"), timeout: 60000 });
      } catch (e) {
        await page.close().catch(()=>{});
        if ((e && e.name === "TimeoutError") || (browser && !browser.isConnected())) transient(e); else fatal(e);
      }
      await page.close();
    }
  } catch (e) {
    if (process.exitCode) throw e;
    console.error(e); process.exitCode = 1;
  } finally {
    await browser.close().catch((e) => { console.error(e); process.exitCode = process.exitCode || 75; });
  }
  // Verify captures exist and are non-trivial.
  try {
    for (const n of ["final-desktop.png", "final-mobile.png"]) {
      const st = statSync(join(output, n));
      console.log(n + " bytes=" + st.size);
      if (st.size < 5000) fatal(new Error("rendering defect: " + n + " too small (" + st.size + " bytes)"));
    }
  } catch (e) { fatal(e); }
})().catch(fatal);
NODE
'
