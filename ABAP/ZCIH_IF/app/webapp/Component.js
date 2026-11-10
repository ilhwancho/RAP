// 앱 시작 시 IfInfo 첫 행을 GET 으로 조회해서 그 Object Page 로 바로 진입.
// initializeFeatureToggles 는 Fiori Elements 의 public 비동기 훅으로,
// AppComponent 가 이 Promise 를 await 한 뒤에 라우팅을 초기화한다 (onServicesStarted).
// → 조회가 끝날 때까지 라우터가 시작되지 않으므로 List Report 가 먼저 보이지 않는다.
sap.ui.define([
  "sap/fe/core/AppComponent",
  "sap/ui/core/routing/HashChanger",
  "sap/base/Log"
], function (AppComponent, HashChanger, Log) {
  "use strict";

  return AppComponent.extend("zcih.ifinfo.Component", {
    metadata: { manifest: "json" },

    initializeFeatureToggles: async function () {
      await AppComponent.prototype.initializeFeatureToggles.apply(this, arguments);

      // 런치패드 셸 제목 메뉴(좌측 상단)에서 상위 페이지(List Report = 앱 제목) 항목 제거.
      // FE 는 첫 페이지가 List Report 면 앱 제목을 hierarchy 루트로 넣는다 (RootViewBaseController.computeTitleHierarchy).
      // 이 시점(onServicesStarted)에는 서비스가 시작돼 있으므로 인스턴스의 setHierarchy 를 감싸 항상 빈 hierarchy 를 넘긴다.
      const oShellServices = this.getShellServices();
      const fnSetHierarchy = oShellServices.setHierarchy.bind(oShellServices);
      oShellServices.setHierarchy = function () {
        return fnSetHierarchy([]);
      };

      const oHash = HashChanger.getInstance();
      if (oHash.getHash()) {
        return;                                   // 딥링크·새로고침·런치패드 시작 파라미터로 들어온 경우는 그대로
      }

      try {
        // GET .../IfInfo?$top=1  (키 필드는 autoExpandSelect 로 자동 포함)
        const [oContext] = await this.getModel().bindList("/IfInfo").requestContexts(0, 1);
        if (oContext) {
          oHash.replaceHash(oContext.getPath().substring(1));   // "IfInfo('IF_CBO_001')"
        }
      } catch (oError) {
        Log.error("IfInfo 조회 실패 - List Report 로 시작", oError);   // 실패해도 앱은 List Report 로 정상 기동
      }
    }
  });
});
