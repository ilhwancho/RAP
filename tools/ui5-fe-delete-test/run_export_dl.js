// FE V4 OP item table: click Export and save the real xlsx (node run_export_dl.js out.xlsx) — MAN=expop_fmt.json|expop_fmt2.json
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const ctx = await b.newContext({ acceptDownloads: true, viewport: { width: 1600, height: 900 } });
  const p = await ctx.newPage();
  const reqs = []; p.on('request', r => { const u = decodeURIComponent(r.url()); if (/_Item/.test(u) && r.method()==='GET') reqs.push(u.split('/0001/')[1]); });
  p.on('console', m => { if (m.type()==='error' && !/CSRF|403|HEAD|preload|EMPTY|unload|CUBE|cache/i.test(m.text())) console.log('  CONSOLE', m.text().slice(0,200)); });
  await p.goto('http://127.0.0.1:8766/index.html#/SalesOrder(SalesOrderUUID=fa163ee8-ec6f-1fe1-b788-a611dbb5ee8f,IsActiveEntity=true)');
  await p.locator('.sapUiMdcTable').first().waitFor({ timeout: 150000 }); await p.waitForTimeout(12000);
  const cells = await p.evaluate(() => [...document.querySelectorAll('[id*="_Item"] .sapMListTblRow, [id*="_Item"] .sapUiTableRow')].slice(0,2).map(e => e.innerText.replace(/\s+/g,' ').trim()));
  console.log('UI5', await p.evaluate(() => sap.ui.version), 'UI rows', JSON.stringify(cells));
  const btn = p.locator('[id$="_Item::LineItem-export-internalSplitBtn-textButton"], [id$="_Item::LineItem-export-internalSplitBtn"] button').first();
  const dl = p.waitForEvent('download', { timeout: 60000 });
  await btn.click({ force: true });
  const d = await dl; await d.saveAs(process.argv[2]); console.log('saved', process.argv[2]);
  [...new Set(reqs)].forEach(x => console.log('  REQ', x.slice(0,300)));
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
