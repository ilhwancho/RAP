// Fiori Elements V2 List Report controller extension (register in manifest.json, see README)
sap.ui.define(["./ValueHelpSortExtension"], function (ValueHelpSortExtension) {
	"use strict";
	return sap.ui.controller("zvhtest.ext.ListReportExt", {
		onInitSmartFilterBarExtension: function (oEvent) {
			ValueHelpSortExtension.register(oEvent.getSource(), {
				// filter field CurrencyCode: value help key = Currency, dialog default sort = Decimals DESC
				CurrencyCode: { key: "Currency", sort: [{ path: "Decimals", descending: true }] }
			});
		}
	});
});
