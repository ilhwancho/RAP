// FE V4 LR: custom column export config + row binding download URL ($select) — usage: MAN=exp.json
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  p.on('console', m => { if (m.type()==='error') console.log('  CONSOLE', m.text().slice(0,200)); });
  await p.goto('http://127.0.0.1:8766/index.html');
  await p.locator('.sapUiMdcTable').first().waitFor({ timeout: 150000 });
  await p.waitForTimeout(8000);
  const r = await p.evaluate(async () => {
    const El = sap.ui.require("sap/ui/core/Element");
    const t = El.registry.filter(e => e.isA("sap.ui.mdc.Table"))[0];
    const cfg = await t._createExportColumnConfiguration();
    const rb = t.getRowBinding(); const url = rb.getDownloadUrl();
    const res = await fetch(url.replace(/\$skip=\d+&?|\$top=\d+&?/g,'') + (url.includes('?')?'&':'?') + '$top=1', { headers: { Accept: 'application/json' } });
    const row = (await res.json()).value?.[0];
    return { ui5: sap.ui.version, cols: t.getColumns().map(c => c.getHeader()),
      export: cfg.map(c => `${c.label} | property=${JSON.stringify(c.property)} | template=${c.template||''}`),
      select: decodeURIComponent(url).match(/\$select=([^&]*)/)?.[1], row };
  });
  console.log(JSON.stringify(r, null, 1));
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
