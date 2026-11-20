const { chromium } = require('playwright');
const out = process.argv[2], tag = process.argv[3];
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const p = await b.newPage({ viewport: { width: 1400, height: 900 } });
  const reqs = [];
  p.on('request', r => { const u = r.url();
    if (u.includes('ZI_CIH_CurrencyVH_Test') && !u.includes('$count')) reqs.push(decodeURIComponent(u.split('ZUI_CIH_SOVHTEST_O2')[1]));
    if (u.includes('$batch') && r.postData()) (r.postData().match(/GET (ZI_CIH_CurrencyVH_Test\?[^ ]+) HTTP/g) || []).forEach(g => reqs.push('[batch] /' + decodeURIComponent(g.slice(4, -5)))); });
  p.on('console', m => { if (m.type() === 'error' && !/ushell|preload|ERR_EMPTY|Navigation|getFilters|RefreshAfterChange|BootstrapConfig/.test(m.text())) console.log('  CONSOLE', m.text().slice(0, 200)); });
  const flush = (t) => { console.log('--- ' + t); const u = [...new Set(reqs.splice(0))]; u.forEach(x => console.log('    REQ ' + x.replace(/&search-focus=Currency&search=&\$select=Currency,Decimals,CurrencyISOCode/, ''))); if (!u.length) console.log('    REQ (none)'); };
  const rows = async () => (await p.locator('.sapMDialog .sapUiTableRow').allInnerTexts()).map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(1, 7).join(' | ');
  await p.goto('http://127.0.0.1:8765/fe.html');
  const vhi = p.locator('[id$="--listReportFilter-filterItemControl_BASIC-CurrencyCode-vhi"]');
  await vhi.first().waitFor({ timeout: 120000 }); await p.waitForTimeout(3000); reqs.splice(0);
  console.log('annotations seen by UI5:', await p.evaluate(() => {
    const mm = sap.ui.getCore().byId(document.querySelector('[id$="--listReportFilter"]').id).getModel().getMetaModel();
    const t = mm.getODataEntityType('cds_zui_cih_sovhtest.ZI_CIH_CurrencyVH_TestType'), s = mm.getODataEntitySet('ZI_CIH_CurrencyVH_Test');
    return JSON.stringify({ PV: Object.keys(t).filter(k => k.includes('PresentationVariant')), SortRestrictions: !!s['Org.OData.Capabilities.V1.SortRestrictions'] });
  }));
  await vhi.first().click({ force: true }); await p.waitForTimeout(6000);
  flush('dialog opened'); console.log('    ROWS ' + await rows());
  console.log('    ext sort applied flag:', await p.evaluate(() => !!window.__zSortApplied));
  await p.screenshot({ path: `${out}/${tag}-open.png` });
  console.log('    table ids', await p.evaluate(() => [...document.querySelectorAll('.sapMDialog .sapUiTable')].map(e => e.id).join(',')));
  const go = p.locator('.sapMDialog button:has-text("Go")'); await go.first().click(); await p.waitForTimeout(5000);
  flush('Go pressed in dialog'); console.log('    ROWS ' + await rows());
  if (process.env.USERSORT) {
    await p.evaluate(() => { const t = sap.ui.core.Element.registry.filter(e => e.isA('sap.ui.table.Table') && e.getId().includes('valueHelpDialog'))[0];
      const c = t.getColumns().find(c => c.getSortProperty() === 'CurrencyISOCode'); t.sort(c, 'Descending'); });
    await p.waitForTimeout(4000); flush('user sorts ISO Code column descending'); console.log('    ROWS ' + await rows());
    await go.first().click(); await p.waitForTimeout(4000); flush('Go pressed again'); console.log('    ROWS ' + await rows());
  }
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });
