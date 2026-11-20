sap.ui.define(["sap/ui/core/Element", "sap/ui/model/Sorter"], function (Element, Sorter) {
  "use strict";
  // CurrencyCode value help dialog: default sort Decimals DESC (instead of key ASC)
  function onBeforeRebind(oEvent) {
    var mBindingParams = oEvent.getParameter("bindingParams");
    var bUserSorted = (mBindingParams.sorter || []).some(function (s) { return s.sPath !== "Currency"; });
    if (!bUserSorted) {                                  // keep a column sort chosen by the user
      mBindingParams.sorter = [new Sorter("Decimals", true)];
    }
  }
  function patch(oVhd) {
    var aSmartTable = oVhd.findAggregatedObjects(true, function (o) { return o.isA("sap.ui.comp.smarttable.SmartTable"); });
    if (aSmartTable.length) {                            // UI5 with internal SmartTable in the dialog
      var oST = aSmartTable[0];
      if (!oST.data("zSortPatched")) {
        oST.data("zSortPatched", true);
        oST.attachBeforeRebindTable(onBeforeRebind);
        oST.rebindTable();                               // initial search already ran -> rebind once with the new sort
      }
      window.__zSortApplied = "smarttable";
      return;
    }
    oVhd.getTableAsync().then(function (oTable) {        // older UI5: plain table bound by ValueHelpProvider
      if (oTable.data("zSortPatched")) { return; }
      oTable.data("zSortPatched", true);
      var fnOrig = oTable.bindRows;
      oTable.bindRows = function (m) { return fnOrig.call(this, Object.assign({}, m, { sorter: [new Sorter("Decimals", true)] })); };
      if (oTable.getBinding("rows")) { oTable.getBinding("rows").sort([new Sorter("Decimals", true)]); }
      window.__zSortApplied = "table";
    });
  }
  function findAndPatch() {
    var aVhd = Element.registry.filter(function (e) {
      return e.isA("sap.ui.comp.valuehelpdialog.ValueHelpDialog") && e.isOpen();
    });
    if (aVhd.length) { patch(aVhd[0]); return true; }
    return false;
  }
  return sap.ui.controller("zvhtest.ext.ListReportExt", {
    onInitSmartFilterBarExtension: function (oEvent) {
      oEvent.getSource().getControlByKey("CurrencyCode").attachValueHelpRequest(function () {
        var n = 0, t = setInterval(function () { if (findAndPatch() || ++n > 50) { clearInterval(t); } }, 50);
      });
    }
  });
});
