// FE V4 List Report: CurrencyCode filter value help (typeahead + dialog)
const { chromium } = require('playwright');
const out = process.argv[2], tag = process.argv[3];
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const p = await b.newPage({ viewport: { width: 1400, height: 900 } });
  const reqs = [];
  p.on('request', r => { const u = r.url();
    if (u.includes('ZI_CIH_CurrencyVH_Test')) reqs.push(decodeURIComponent(u.split('/0001/')[1] || u));
    if (u.includes('$batch') && r.postData()) (r.postData().match(/GET (ZI_CIH_CurrencyVH_Test[^ ]*) HTTP/g) || []).forEach(g => reqs.push('[batch] ' + decodeURIComponent(g.slice(4, -5)))); });
  p.on('console', m => { if (m.type() === 'error' && !/ushell|preload|ERR_EMPTY|BootstrapConfig|Navigation/.test(m.text())) console.log('  CONSOLE', m.text().slice(0, 200)); });
  const flush = (t) => { console.log('--- ' + t); const u = [...new Set(reqs.splice(0))]; u.forEach(x => console.log('    REQ ' + x)); if (!u.length) console.log('    REQ (none)'); };
  const rows = async () => (await p.locator('.sapMDialog .sapUiTableRow, .sapMDialog .sapMListItems tr, .sapMPopover .sapMListItems tr').allInnerTexts())
      .map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 7).join(' | ');
  await p.goto('http://127.0.0.1:8765/fe4.html');
  const field = p.locator('[id$="FilterField::CurrencyCode-inner-inner"]');
  await field.first().waitFor({ timeout: 150000 }); await p.waitForTimeout(4000); reqs.splice(0);
  console.log('FE V4 loaded, UI5 ' + await p.evaluate(() => sap.ui.version));
  // typeahead
  await field.first().click(); await field.first().pressSequentially('E', { delay: 150 }); await p.waitForTimeout(5000);
  flush('typeahead "E"'); console.log('    ROWS ' + await rows());
  await p.keyboard.press('Escape'); await field.first().fill(''); await p.waitForTimeout(1000); reqs.splice(0);
  // dialog
  await p.locator('[id$="FilterField::CurrencyCode-inner-vhi"]').first().click({ force: true }); await p.waitForTimeout(7000);
  flush('value help dialog'); console.log('    ROWS ' + await rows());
  await p.screenshot({ path: `${out}/${tag}-dialog.png` });
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
