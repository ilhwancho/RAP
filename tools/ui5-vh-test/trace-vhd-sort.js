// VHD 내부 SmartTable 의 rebind 시점 sorter/_aInitialSorters/_oCurrentVariant 추적 + _oCurrentVariant="STANDARD" 인과 실험 (fwd.py 실행 상태에서)
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1' } });
  const p = await b.newPage({ viewport: { width: 1400, height: 900 } });
  p.on('console', m => { if (m.text().startsWith('ZDBG')) console.log(m.text()); });
  await p.goto('http://127.0.0.1:8765/fe.html');
  const vhi = p.locator('[id$="--listReportFilter-filterItemControl_BASIC-CurrencyCode-vhi"]');
  await vhi.first().waitFor({ timeout: 120000 }); await p.waitForTimeout(3000);
  await p.evaluate(() => {
    const ST = sap.ui.require('sap/ui/comp/smarttable/SmartTable');
    const s = (a) => JSON.stringify((a || []).map(x => x.sPath + (x.bDescending ? ' desc' : ' asc')));
    const origFire = ST.prototype.fireBeforeRebindTable;
    ST.prototype.fireBeforeRebindTable = function (m) {
      if (this.getId().includes('valueHelpDialog')) {
        console.log('ZDBG before handlers: sorter=' + s(m.bindingParams.sorter) + ' initialSorters=' + JSON.stringify(this._aInitialSorters) +
          ' _oCurrentVariant=' + String(this._oCurrentVariant) + ' personalisationData=' + JSON.stringify(this._getTablePersonalisationData()) + ' custom=' + JSON.stringify(m.bindingParams.parameters.custom));
        const r = origFire.apply(this, arguments);
        console.log('ZDBG after handlers:  sorter=' + s(m.bindingParams.sorter));
        return r;
      }
      return origFire.apply(this, arguments);
    };
    const origStore = ST.prototype._storeInitialColumnSettings;
    ST.prototype._storeInitialColumnSettings = function () { const r = origStore.apply(this, arguments);
      if (this.getId().includes('valueHelpDialog')) console.log('ZDBG _storeInitialColumnSettings -> ' + JSON.stringify(this._aInitialSorters)); return r; };
  });
  await vhi.first().click({ force: true }); await p.waitForTimeout(6000);
  console.log('ZDBG --- experiment: set _oCurrentVariant = "STANDARD" and rebindTable()');
  await p.evaluate(() => { const st = sap.ui.core.Element.registry.filter(e => e.isA('sap.ui.comp.smarttable.SmartTable') && e.getId().includes('valueHelpDialog'))[0];
    st._oCurrentVariant = 'STANDARD'; st.rebindTable(); });
  await p.waitForTimeout(4000);
  console.log('ZDBG rows: ' + (await p.locator('.sapMDialog .sapUiTableRow').allInnerTexts()).map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(1, 6).join(' | '));
  console.log('ZDBG --- press Go');
  await p.locator('.sapMDialog button:has-text("Go")').first().click(); await p.waitForTimeout(4000);
  await b.close();
})();
