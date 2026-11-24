# Fiori Elements V4: 리스트 리포트·오브젝트 페이지 Delete 버튼 숨기기

2026-11-24 실측 + sap.fe 소스(UI5 1.154.0, ui5.sap.com `*-dbg.js`) 분석.
테스트: 판매오더 샘플 `ZUI_CIH_SALESORDER_O4` (`/SalesOrder`, managed + draft), 하네스 `tools/ui5-fe-delete-test/`.
Z5U 런치패드 UI5 는 1.148.12 (`docs/cds/value-help-presentation-variant-v2.md` 참고).

## 결론
| 방법 | 리스트 리포트 테이블 | 오브젝트 페이지 헤더 | UI5 버전 |
|---|---|---|---|
| manifest `controlConfiguration` → `@...LineItem` → `actions` → `"StandardAction::Delete": {"visible": false}` | ✅ | – | **1.151 이상만**. 1.120/1.136/1.145/1.148/1.150 은 무시됨 |
| manifest `content.header.actions` → `"DeleteAction": {"visible": false}` | – | ✅ | 1.148 에서도 동작 (사용자 확인) |
| 앱 로컬 주석 `UI.DeleteHidden` = true | ✅ | ✅ | 1.120, 1.148 확인 |
| 앱 로컬 주석 `Capabilities.DeleteRestrictions/Deletable` = false | ✅ | ✅ | 버전 무관 (판단 기준값 자체) |
| 프로젝션 BDEF 에서 `use delete;` 제거 | ✅ | ✅ | 백엔드에서 실제 삭제도 막음 |

- manifest·로컬 주석 방식은 **화면만** 바꾼다. OData `DELETE` 는 여전히 받으므로, 실제로 막으려면 BDEF.
- 오브젝트 페이지 안의 아이템 테이블은 `"_Item/@com.sap.vocabularies.UI.v1.LineItem"` 처럼 내비게이션 경로를 붙인 키에 `StandardAction::Delete`.

## manifest 예
```json
"SalesOrderList": { "options": { "settings": {
  "controlConfiguration": { "@com.sap.vocabularies.UI.v1.LineItem": {
    "actions": { "StandardAction::Delete": { "visible": false } } } } } } },
"SalesOrderObjectPage": { "options": { "settings": {
  "content": { "header": { "actions": { "DeleteAction": { "visible": false } } } } } } }
```

## 로컬 주석 예 (manifest `dataSources` 에 `ODataAnnotation` 으로 연결)
```xml
<Annotations Target="com.sap.gateway.srvd.zui_cih_salesorder.v0001.Container/SalesOrder">
  <Annotation Term="UI.DeleteHidden" Bool="true"/>
</Annotations>
```
- Target `<Namespace>.<Container>/<EntitySet>` 은 **컨테이너 안의 엔티티셋** 경로(컨테이너 자체가 아님). 엔티티 타입은 `<Namespace>.<EntityType>`.
- Namespace·Container·EntitySet 이름은 `$metadata` 의 `<Schema Namespace>`, `<EntityContainer Name>`, `<EntitySet Name>`.

## 소스 근거 (sap.fe 1.154)
- `sap/fe/core/converters/controls/Common/table/StandardActions.js`
  - `StandardActionKeys.Delete = "StandardAction::Delete"`
  - `getDeleteVisibility`: LR 은 `not(DeleteHidden) && isDeletable`, OP 테이블은 `&& UI.IsEditable` 추가.
- `.../Common/Table.js` `getTableActions`: `StandardAction::` 로 시작하는 manifest 액션을 표준 액션 위에 `visible/enabled/position...` overwrite (1.151 미만엔 이 처리가 없어 무시됨).
- `.../objectPage/HeaderAndFooterAction.js`: OP 헤더 Delete 키 `"DeleteAction"`, `DeleteRestrictions.Deletable !== false` 일 때만 생성, `UI.DeleteHidden` 반영.
  `templates/ObjectPageConverter.js` `getHeaderActions` 가 `settings.content.header.actions` 로 overwrite.
- `sap/fe/core/templating/DataModelPathHelper.js` `isPathDeletable` → `checkOnPath`:
  1. 부모 엔티티셋 `NavigationRestrictions/RestrictedProperties[NavigationProperty=경로]/DeleteRestrictions`
  2. 타겟 엔티티셋 `Capabilities.DeleteRestrictions`
  3. 타겟 엔티티셋이 없으면(containment) → 내비게이션 프로퍼티의 Capabilities → **엔티티 타입의 Capabilities**
  4. (1.154) 파라미터 엔티티(`Common.ResultContext`)면 시작 엔티티셋의 Capabilities

## 파라미터 CDS (with parameters) 주의
- V4 에서 `EntitySet ZC_X`(파라미터 타입) → `NavigationProperty Set` (`ContainsTarget="true"`) → 결과 행. 테이블은 `ZC_X(p_...)/Set` 바인딩.
- 결과 행 전용 엔티티셋이 없어서 **엔티티셋 타겟 `DeleteRestrictions` 는 무시**되고, **엔티티 타입 타겟은 동작**(위 3단계). 사용자 앱에서 확인.
- 엔티티셋 기준으로 하려면 `Container/ZC_X` 에 `Capabilities.NavigationRestrictions` 로 `NavigationPropertyPath="Set"` + `DeleteRestrictions/Deletable=false` (1단계, ⚠️ 소스 분석 기준, 미실측).
- `ZC_X` 찾기: `$metadata` 에서 엔티티 타입에 파라미터 필드만 있고 `Set` containment 내비게이션을 가진 `EntitySet`. manifest `contextPath`(`/ZC_X/Set`) 나 서비스 정의 `expose ... as <별칭>` 으로도 확인.
