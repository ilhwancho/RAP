// usage: node run3.js <outdir> <tag>   (forwarder must be running)
const { chromium } = require('playwright');
const out = process.argv[2], tag = process.argv[3];
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const reqs = [];
  const newPage = async () => {
    const p = await b.newPage({ viewport: { width: 1400, height: 900 } });
    p.on('request', r => { const u = r.url();
      if (u.includes('ZI_CIH_CurrencyVH_Test') && !u.includes('$count')) reqs.push(decodeURIComponent(u.replace('http://127.0.0.1:8765/sap/opu/odata/sap/ZUI_CIH_SOVHTEST_O2', '')));
      if (u.includes('$batch') && r.postData()) (r.postData().match(/GET (ZI_CIH_CurrencyVH_Test\?[^ ]+) HTTP/g) || []).forEach(g => reqs.push('[batch] /' + decodeURIComponent(g.slice(4, -5)))); });
    p.on('console', m => { if (m.type() === 'error' || m.text().includes('ValueListProvider')) console.log('  CONSOLE', m.text().slice(0, 160)); });
    return p;
  };
  const flush = (t) => { console.log('--- ' + t); const u = [...new Set(reqs.splice(0))]; u.forEach(x => console.log('    REQ ' + x)); if (!u.length) console.log('    REQ (none)'); };
  const rows = async (p) => (await p.locator('.sapMDialog .sapUiTableRow, .sapMDialog tbody tr').allInnerTexts())
      .map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 7).join(' | ');
  const esc = (id) => '#' + id.replace(/([.:])/g, '\\$1');
  const openDialog = async (p, vhiSel, name) => {
    await p.locator(vhiSel).first().click({ timeout: 10000, force: true }); await p.waitForTimeout(5000);
    const go = p.locator('.sapMDialog button:has-text("Go")'); if (await go.count()) { await go.first().click(); await p.waitForTimeout(5000); }
    flush(name); console.log('    ROWS ' + await rows(p));
    await p.screenshot({ path: `${out}/${tag}-${name}.png` });
    await p.keyboard.press('Escape'); await p.waitForTimeout(1000);
  };
  const step = async (n, f) => { try { await f(); } catch (e) { console.log('!! ' + n + ': ' + e.message.split('\n')[0]); reqs.splice(0); } };

  // (a)+(b) harness page: SmartFilterBar + SmartField
  await step('harness', async () => {
    const p = await newPage();
    await p.goto('http://127.0.0.1:8765/index.html');
    await p.waitForFunction(() => window.__ready === true, null, { timeout: 90000 }); await p.waitForTimeout(3000); reqs.splice(0);
    const fid = await p.evaluate(() => sap.ui.getCore().byId('sfb').determineControlByName('CurrencyCode').getId());
    await step('a SFB dialog', () => openDialog(p, esc(fid) + '-vhi', 'a-SmartFilterBar-dialog'));
    const sfInfo = await p.evaluate(() => { const f = sap.ui.getCore().byId('sf'); return 'editable=' + f.getEditable() + ' mode=' + f.getMode(); });
    console.log('SmartField: ' + sfInfo);
    await p.evaluate(() => sap.ui.getCore().byId('sf').setEditable(true)); await p.waitForTimeout(3000); reqs.splice(0);
    console.log('SmartField after setEditable: ' + await p.evaluate(() => sap.ui.getCore().byId('sf').getMode()));
    await step('b SmartField dialog', () => openDialog(p, '#sf [id$="-vhi"]', 'b-SmartField-dialog'));
    await p.close();
  });
  // (c) Fiori Elements V2 List Report
  await step('fe', async () => {
    const p = await newPage();
    await p.goto('http://127.0.0.1:8765/fe.html');
    const loc = p.locator('[id$="--listReportFilter-filterItemControl_BASIC-CurrencyCode-vhi"]');
    await loc.first().waitFor({ timeout: 120000 }); await p.waitForTimeout(3000); reqs.splice(0);
    console.log('FE: UI5 ' + await p.evaluate(() => sap.ui.version) + ', LR filter bar found');
    await step('c FE dialog', () => openDialog(p, '[id$="--listReportFilter-filterItemControl_BASIC-CurrencyCode-vhi"]', 'c-FE-ListReport-dialog'));
    await p.close();
  });
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
