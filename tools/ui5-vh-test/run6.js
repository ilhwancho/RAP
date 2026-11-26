// FE V4 List Report: parameterized value help (ZI_CIH_CurrVHParam / ZI_CIH_CurrVHSys) filter fields - dialog requests/rows
const { chromium } = require('playwright');
const out = process.argv[2] || ".";
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const p = await b.newPage({ viewport: { width: 1400, height: 900 } });
  const reqs = [];
  p.on('request', r => { const u = decodeURIComponent(r.url());
    if (u.includes('/sap/opu/')) reqs.push(r.method()+' ' + u.split('/sap/opu/odata4/sap/')[1]);
    if (u.includes('$batch') && r.postData()) (r.postData().match(/GET ([^ ]*) HTTP/g) || []).forEach(g => reqs.push('[batch] ' + decodeURIComponent(g.slice(4, -5)))); });
  p.on('response', async r => { const u = r.url(); if (u.includes('$batch')) { const t = await r.text().catch(()=> ''); const e = t.match(/"message"\s*:\s*"[^"]*"/g); if (e) reqs.push('  ERR ' + e.join(' ; ').slice(0,300)); const st = t.match(/HTTP\/1.1 \d+/g); if (st) reqs.push('  STATUS ' + st.join(',')); } });
  p.on('console', m => { if (['error','warning'].includes(m.type()) && /odata|ValueList|Set|ZI_CIH|path|binding|Parameter/i.test(m.text())) console.log('  CONSOLE', m.text().slice(0, 250)); });
  const flush = (t) => { console.log('--- ' + t); const u = [...new Set(reqs.splice(0))]; u.forEach(x => console.log('    ' + x)); if (!u.length) console.log('    REQ (none)'); };
  const rows = async () => (await p.locator('.sapMDialog .sapUiTableRow, .sapMDialog .sapMListItems tr, .sapMPopover .sapMListItems tr').allInnerTexts())
      .map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 8).join(' | ');
  await p.goto('http://127.0.0.1:8765/fe4.html');
  await p.locator('[id$="FilterField::CurrConst-inner-inner"]').first().waitFor({ timeout: 150000 }); await p.waitForTimeout(4000); reqs.splice(0);
  console.log('FE V4 loaded, UI5 ' + await p.evaluate(() => sap.ui.version));
  for (const [f, pre] of [['CurrencyCode'], ['CurrConst'], ['CurrSys'], ['CurrNone'], ['CurrElem'], ['CurrElem', '3']]) {
    if (pre) { const m = p.locator('[id$="FilterField::MinDecimals-inner-inner"]').first(); await m.click(); await m.fill(pre); await m.press('Enter'); await p.waitForTimeout(1500); reqs.splice(0); }
    await p.locator(`[id$="FilterField::${f}-inner-vhi"]`).first().click({ force: true }); await p.waitForTimeout(7000);
    flush(`${f} dialog${pre ? ' (MinDecimals=' + pre + ')' : ''}`); console.log('    ROWS ' + await rows());
    await p.screenshot({ path: `${out}/pvh-${f}${pre||''}.png` });
    await p.keyboard.press('Escape'); await p.waitForTimeout(1500);
    const c = p.locator('.sapMDialog button:has-text("Cancel")'); if (await c.count()) { await c.first().click(); await p.waitForTimeout(1000); }
    reqs.splice(0);
  }
  // typeahead on CurrConst
  const fc = p.locator('[id$="FilterField::CurrConst-inner-inner"]').first(); await fc.click(); await fc.pressSequentially('K', { delay: 150 }); await p.waitForTimeout(5000);
  flush('CurrConst typeahead "K"'); console.log('    ROWS ' + await rows());
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
