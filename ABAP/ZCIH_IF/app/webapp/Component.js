// 앱 시작 시 IfInfo 첫 행을 GET 으로 조회해서 그 Object Page 로 바로 진입.
// initializeFeatureToggles 는 Fiori Elements 의 public 비동기 훅으로,
// AppComponent 가 이 Promise 를 await 한 뒤에 라우팅을 초기화한다 (onServicesStarted).
// → 조회가 끝날 때까지 라우터가 시작되지 않는다.
// manifest 에 List Report 라우트가 없으므로(빈 해시와 매칭되는 라우트 없음) 해시를 못 정하면 빈 화면이 된다 → 실패 시 오류 표시.
sap.ui.define([
  "sap/fe/core/AppComponent",
  "sap/ui/core/routing/HashChanger",
  "sap/base/Log",
  "sap/m/MessageBox"
], function (AppComponent, HashChanger, Log, MessageBox) {
  "use strict";

  return AppComponent.extend("zcih.ifinfo.Component", {
    metadata: { manifest: "json" },

    initializeFeatureToggles: async function () {
      await AppComponent.prototype.initializeFeatureToggles.apply(this, arguments);

      const oHash = HashChanger.getInstance();
      if (oHash.getHash()) {
        return;                                   // 새로고침·런치패드 시작 파라미터로 들어온 경우는 그대로
      }

      try {
        // GET .../IfInfo?$top=1  (키 필드는 autoExpandSelect 로 자동 포함)
        const [oContext] = await this.getModel().bindList("/IfInfo").requestContexts(0, 1);
        if (!oContext) {
          throw new Error("인터페이스 정보(IfInfo)가 없습니다.");
        }
        oHash.replaceHash(oContext.getPath().substring(1));   // "IfInfo('IF_CBO_001')"
      } catch (oError) {
        Log.error("IfInfo 조회 실패", oError);
        MessageBox.error(oError.message);
      }
    }
  });
});
