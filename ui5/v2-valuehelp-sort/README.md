# OData V2 값 도움말 다이얼로그 기본 정렬 (Fiori Elements V2 컨트롤러 확장)

V2(`sap.ui.comp`) 값 도움말 다이얼로그는 `@UI.presentationVariant` 정렬을 무시하고 항상 키 오름차순으로 조회한다.
어노테이션·manifest 설정으로는 바꿀 수 없어서(실측), List Report 컨트롤러 확장으로 다이얼로그 기본 정렬을 지정한다.
배경·원인·테스트 결과: `docs/cds/value-help-presentation-variant-v2.md`

## 파일
- `ext/ValueHelpSortExtension.js` : 재사용 헬퍼. `register(oSmartFilterBar, { 필드: { key, sort: [{ path, descending }] } })`
- `ext/ListReportExt.controller.js` : List Report 확장 예 (`CurrencyCode` 필드 → `Decimals` 내림차순)

## 적용
1. 두 파일을 앱의 `webapp/ext/` 에 넣고, 확장 컨트롤러 이름(`sap.ui.controller("<앱 id>.ext.ListReportExt", …)`)과 설정(필드명, VH 키, 정렬)을 맞춘다.
2. `manifest.json`:
```json
"sap.ui5": {
  "extends": { "extensions": { "sap.ui.controllerExtensions": {
    "sap.suite.ui.generic.template.ListReport.view.ListReport": { "controllerName": "<앱 id>.ext.ListReportExt" }
  } } }
}
```

## 동작
1. 필터 필드의 `valueHelpRequest` 때 열린 `ValueHelpDialog` 를 찾는다.
2. 다이얼로그 내부 SmartTable 의 `beforeRebindTable` 에서 sorter 를 지정한다 (사용자가 다른 컬럼으로 정렬했으면 그대로 둠). 붙인 직후 `rebindTable()` 한 번.
3. 내부 SmartTable 이 없는 UI5 버전은 다이얼로그 테이블 `bindRows` 를 감싸는 fallback (미검증).

## 검증 (2026-11-21, 테스트 서비스 `ZUI_CIH_SOVHTEST_O2`, 로컬 FE V2 List Report)
| UI5 | 열 때 | 다이얼로그 Go | 사용자 컬럼 정렬(ISO Code desc) 후 Go |
|---|---|---|---|
| 1.154.0 | `Currency asc` 1회 → `Decimals desc` | `Decimals desc` | `CurrencyISOCode desc` 유지 |
| 1.148.12 (Z5U 런치패드) | 동일 | 동일 | 동일 |

## 한계
- 공개 API 가 아닌 내부 구조(다이얼로그 안 SmartTable, registry 에서 열린 VHD 찾기)에 의존 → UI5 업그레이드 때 재검증 필요.
- 처음 열 때 요청 2회 (기본 검색 후 재조회).
- List Report 필터바만 대상. Object Page SmartField 값 도움말은 미적용·미검증. 자동완성(typeahead) 정렬은 바꾸지 않음.
- OData V4(sap.fe) 는 어노테이션(`presentationVariantQualifier` / `@UI.presentationVariant`)만으로 정렬되므로 이 확장이 필요 없다.
