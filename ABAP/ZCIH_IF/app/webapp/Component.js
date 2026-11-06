// List Report 를 건너뛰고 Object Page 로 바로 진입 (⚠️ 실제 동작 확인 필요)
sap.ui.define([
  "sap/fe/core/AppComponent",
  "sap/ui/core/routing/HashChanger"
], function (AppComponent, HashChanger) {
  "use strict";

  return AppComponent.extend("zcih.ifinfo.Component", {
    metadata: { manifest: "json" },

    init: function () {
      const oHash = HashChanger.getInstance();
      if (!oHash.getHash()) {                       // 최초 진입 시에만
        oHash.replaceHash("IfInfo('IF_CBO_001')");
      }
      AppComponent.prototype.init.apply(this, arguments);
    }
  });
});
