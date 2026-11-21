/*
 * OData V2 (sap.ui.comp / Fiori Elements V2) value help dialog default sort
 *
 * Why: in V2 the value help dialog ignores UI.PresentationVariant and always sorts by the key ascending
 *      (see docs/cds/value-help-presentation-variant-v2.md). This helper sets a default sort for the
 *      dialog table of selected SmartFilterBar fields.
 *
 * How: when the field fires valueHelpRequest, it finds the opened ValueHelpDialog, takes its internal
 *      SmartTable and adds sorters in beforeRebindTable (only if the user did not sort a column).
 *      Fallback for UI5 versions without the internal SmartTable: wraps bindRows of the dialog table.
 *
 * Limits: relies on the internal structure of ValueHelpDialog (internal SmartTable). Verified on UI5 1.154 / 1.148.
 *         On first open, the default search (key asc) runs once, then the table is rebound with this sort.
 */
sap.ui.define(["sap/ui/core/Element", "sap/ui/model/Sorter"], function (Element, Sorter) {
	"use strict";

	function toSorters(aSort) {
		return aSort.map(function (s) { return new Sorter(s.path, !!s.descending); });
	}

	function patchSmartTable(oSmartTable, aSort, sKey) {
		if (oSmartTable.data("zVhSortPatched")) { return; }
		oSmartTable.data("zVhSortPatched", true);
		oSmartTable.attachBeforeRebindTable(function (oEvent) {
			var mBindingParams = oEvent.getParameter("bindingParams");
			var aCurrent = mBindingParams.sorter || [];
			// keep a column sort chosen by the user (anything other than the default key sort)
			var bUserSorted = aCurrent.some(function (s) { return s.sPath !== sKey; });
			if (!bUserSorted) {
				mBindingParams.sorter = toSorters(aSort);
			}
		});
		oSmartTable.rebindTable(); // the initial search already ran with key asc -> rebind once
	}

	function patchPlainTable(oTable, aSort) {
		if (oTable.data("zVhSortPatched")) { return; }
		oTable.data("zVhSortPatched", true);
		var fnBindRows = oTable.bindRows;
		oTable.bindRows = function (mParams) {
			return fnBindRows.call(this, Object.assign({}, mParams, { sorter: toSorters(aSort) }));
		};
		if (oTable.getBinding("rows")) {
			oTable.getBinding("rows").sort(toSorters(aSort));
		}
	}

	function patchOpenDialog(aSort, sKey) {
		var aDialogs = Element.registry.filter(function (e) {
			return e.isA("sap.ui.comp.valuehelpdialog.ValueHelpDialog") && e.isOpen();
		});
		if (!aDialogs.length) { return false; }
		var oDialog = aDialogs[0];
		var aSmartTables = oDialog.findAggregatedObjects(true, function (o) {
			return o.isA("sap.ui.comp.smarttable.SmartTable");
		});
		if (aSmartTables.length) {
			patchSmartTable(aSmartTables[0], aSort, sKey);
		} else {
			oDialog.getTableAsync().then(function (oTable) { patchPlainTable(oTable, aSort); });
		}
		return true;
	}

	return {
		/**
		 * Registers default dialog sorts for SmartFilterBar fields.
		 * @param {sap.ui.comp.smartfilterbar.SmartFilterBar} oSmartFilterBar the filter bar
		 * @param {object} mConfig { "<filter field name>": { key: "<value list key property>",
		 *                                                    sort: [{ path: "<property>", descending: true }] } }
		 */
		register: function (oSmartFilterBar, mConfig) {
			Object.keys(mConfig).forEach(function (sField) {
				var oControl = oSmartFilterBar.getControlByKey(sField);
				if (!oControl || !oControl.attachValueHelpRequest) { return; }
				var oCfg = mConfig[sField];
				oControl.attachValueHelpRequest(function () {
					var n = 0;
					var t = setInterval(function () {
						if (patchOpenDialog(oCfg.sort, oCfg.key) || ++n > 50) { clearInterval(t); }
					}, 50);
				});
			});
		}
	};
});
