const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const p = await b.newPage({ viewport: { width: 1400, height: 900 } });
  p.on('console', m => { if (m.type()==='error' && /fe|Table|manifest/i.test(m.text())) console.log('  CONSOLE', m.text().slice(0,200)); });
  await p.goto('http://127.0.0.1:8766/index.html');
  await p.locator('.sapUiMdcTable, .sapUiCompSmartTable, [id*="::Table"]').first().waitFor({ timeout: 150000 });
  await p.waitForTimeout(8000);
  const r = await p.evaluate(() => {
    const ids = [...document.querySelectorAll('[id*="StandardAction::Delete"],[id*="::Delete"]')].map(e=>e.id).filter(i=>!/-(inner|content|BDI)/.test(i));
    const C = sap.ui.require("sap/ui/core/Element");
    return { ui5: sap.ui.version, del: ids.map(i => { const c = C && C.getElementById ? C.getElementById(i) : sap.ui.getCore().byId(i); return i + ' visible=' + (c && c.getVisible ? c.getVisible() : '?'); }),
      toolbar: [...document.querySelectorAll('.sapMOTB button, [id*="::Table"] .sapMTB button')].map(e=>e.innerText.trim()).filter(Boolean) };
  });
  console.log(JSON.stringify(r, null, 1));
  await p.screenshot({ path: process.argv[2] });
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
