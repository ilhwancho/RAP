# 값 도움말 정렬: UI.presentationVariant (OData V2)

2026-11-20 실측. Z5U(Release 920), SAPUI5 1.154 (`sap.ui.comp`, ui5.sap.com).
테스트 객체: 패키지 `ZCIH_VH_TEST` (`ABAP/ZCIH_VH_TEST/`), 바인딩 `ZUI_CIH_SOVHTEST_O2` (V2 UI).
- VH: `ZI_CIH_CurrencyVH_Test` (I_Currency 래핑, `@UI.presentationVariant` qualifier `SortDesc`, Currency DESC)
- 소비: `ZC_CIH_SOVHTest.CurrencyCode`

## 결론
| 경우 | 결과 |
|---|---|
| A. 일반 VH + `presentationVariantQualifier` 지정 | ❌ **값 도움말이 깨짐**. 자동완성이 `GET .../null?$filter=startswith(undefined,E)` → 404, 다이얼로그 빈 화면, SmartField `TypeError ... reading 'fields'` |
| B. 일반 VH, qualifier 미지정 (PV 는 VH 엔티티에만) | ✅ 동작. 단 PV 정렬 **무시**: 자동완성은 `$orderby` 없음, 다이얼로그는 `$orderby=Currency asc` (키 고정) |
| C. 고정값(드롭다운) + qualifier 지정 | ❌ 깨짐 (`Missing primary ValueListAnnotation`) |
| D. 고정값(드롭다운), qualifier 미지정 | ✅ **PV 정렬 적용**: `$orderby=Currency desc`, 항목 ZWL, ZWG, ZMW… |

→ V2 에서 PV 정렬을 쓰려면 **고정값 드롭다운 + qualifier 미지정** 조합만 된다. A·C 는 메타데이터 조작(qualifier 제거, `Common.ValueListWithFixedValues` 주입)으로 A/B 비교한 뒤, D 를 실제 CDS 로 다시 확인함.

## 다이얼로그 추가 검증 (같은 날)
일반 값 도움말(`sap:value-list="standard"`), 소비 쪽 qualifier 없음, PV 정렬 필드를 **키가 아닌 `Decimals` DESC** 로 바꿔 기본 정렬(`Currency asc`)과 구분되게 함.

| PV | (a) SmartFilterBar 다이얼로그 | (b) SmartField 다이얼로그 | (c) Fiori Elements V2 List Report 필터바 다이얼로그 |
|---|---|---|---|
| V1. qualifier `SortDesc` | `$orderby=Currency asc` | `Currency asc` | `Currency asc` (`$batch`) |
| V2. qualifier 없음 | `Currency asc` | `Currency asc` | `Currency asc` (`$batch`) |

- UI5 버전별 (V2 PV 기준): 1.154.0, 1.144.1, 1.120.53 → (a)(b)(c) 모두 `Currency asc`. 1.108.57, 1.96.51 → (a)(b) `Currency asc`, (c)는 테스트용 FE 앱이 그 버전에서 안 떠서 미검증.
- 대조: 같은 PV(qualifier 없음)로 고정값 드롭다운을 띄우면 `$orderby=Decimals desc` → PV 는 UI5 에 정상 전달되고, 다이얼로그만 안 씀.
- (b) 는 읽기 전용 서비스라 `$metadata` 엔티티셋을 `sap:creatable/updatable="true"` 로 바꿔 서빙하고 `setEditable(true)` 로 편집 모드를 만든 상태에서 측정(쓰기 요청은 없음).
- (c) 는 로컬에 만든 최소 FE V2 앱(`sap.suite.ui.generic.template.ListReport`, manifest 에 `_VAN` 주석 연결).
- 판정은 요청 URL 의 `$orderby` 와 다이얼로그 첫 행(AED, AFN, ALL… = 통화 오름차순; PV 가 먹었다면 소수 3자리 통화가 먼저 나와야 함).

## 다이얼로그 정렬 커스터마이징 방법 테스트 (FE V2 List Report, UI5 1.154)
| 방법 | 결과 |
|---|---|
| manifest 설정 | ❌ FE V2 List Report 설정·SmartFilterBar `ControlConfiguration` 에 값 도움말 정렬 항목 없음 (소스 확인) |
| L1. 로컬 주석 `UI.PresentationVariant#LocalSort` (Decimals desc) | ❌ UI5 메타모델엔 들어오지만 다이얼로그는 `$orderby=Currency asc` |
| L2. 로컬 주석 `Capabilities.SortRestrictions/NonSortableProperties = Currency` (VH 엔티티셋) | △ 다이얼로그 요청에서 `$orderby` 가 빠짐. 그러나 백엔드가 키 순으로 반환(AED, AFN…). 대신 Currency 컬럼 정렬도 막힘 |
| L3. 확장에서 `table.sort(Decimals, Descending)` | ❌ 다음 rebind 때 provider 가 컬럼 정렬 상태를 리셋 → `Currency asc` |
| L3b. 확장에서 내부 `sap.ui.table.Table.bindRows` 오버라이드 | △ 열 때만 적용. 1.154 다이얼로그는 내부 SmartTable(`-valueHelpDialog-table`)이 다시 바인딩해서 Go 누르면 원복 |
| **L3c. manifest 로 ListReport 컨트롤러 확장 등록 + 다이얼로그 내부 SmartTable `beforeRebindTable` 에서 sorter 지정** | ✅ 열 때·Go 후 모두 `$orderby=Decimals desc` (BHD, IQD, JOD… 소수 3자리 먼저). 사용자가 컬럼 정렬(ISO Code desc)하면 그쪽 우선, Go 후에도 유지 |

L3c 주의:
- 다이얼로그를 처음 열 때 기본 검색(`Currency asc`)이 먼저 한 번 나가고, 확장이 `rebindTable()` 로 다시 조회 → 요청 2회.
- private 구조(다이얼로그 안의 SmartTable, `valueHelpRequest` 후 열린 VHD 를 registry 에서 찾기)에 기대므로 UI5 버전 바뀌면 깨질 수 있음. 1.154 에서만 실측.
  내부 SmartTable 이 없는 버전용으로 `bindRows` 오버라이드 fallback 을 넣었지만 그 경로는 미검증.
- 코드: `tools/ui5-vh-test/feapp/ext/ListReportExt.controller.js`, manifest 등록:
```json
"sap.ui5": { "extends": { "extensions": { "sap.ui.controllerExtensions": {
  "sap.suite.ui.generic.template.ListReport.view.ListReport": { "controllerName": "zvhtest.ext.ListReportExt" } } } } }
```
- Object Page 의 SmartField 값 도움말에는 별도 확장(`onInitSmartFilterBarExtension` 이 아니라 Object Page 쪽 훅)이 필요 → 미검증.

## 왜 그런가
- 백엔드는 정상: `$metadata` 의 `Common.ValueList` 에 `PresentationVariantQualifier` 가 나가고(`CL_SADL_GW_VOCAN_EXPOSURE`),
  `UI.PresentationVariant#SortDesc` 는 V2 별도 주석 파일(`/sap/opu/odata/IWFND/CATALOGSERVICE;v=2/Annotations(TechnicalName='<바인딩>_VAN',Version='0001')/$value`)에 나간다.
- UI5 `MetadataAnalyser` 는 qualifier 가 없는(primary) ValueList 라도 `PresentationVariantQualifier` 가 있으면 `primaryValueListAnnotationWithPVQualifier` 로 따로 분류한다(소스 주석: "TODO … Ignore ValueList with PresentationVariantQualifier").
  `ODataControlFactory`·`ValueListProvider` 는 `primaryValueListAnnotation` 만 보므로 VH 가 없는 것처럼 동작해 깨진다.
- PV 정렬은 `ValueListProvider._handlePresentationVariantSortOrderAnnotation` 이 VH 엔티티 타입의 `UI.PresentationVariant#<q>` 를 직접 찾아서 쓴다(ValueList 의 qualifier 는 안 씀). 드롭다운 템플릿에서만 sorter 를 쓰고, sortOrder 첫 항목만 쓴다.
- 다이얼로그(`ValueHelpProvider`)는 항상 `new Sorter(this.sKey)` (키 오름차순).

## V2 에서 쓰는 형태
```cds
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS        // → sap:value-list="fixed-values" (드롭다운)
@UI.presentationVariant: [{ qualifier: 'SortDesc',
                            sortOrder: [{ by: 'Currency', direction: #DESC }] }]
define view entity ZI_CIH_CurrencyVH_Test as select from I_Currency { key Currency, ... }

// 소비 쪽: presentationVariantQualifier 를 넣지 않는다 (V2 에서 VH 가 깨짐)
@Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CIH_CurrencyVH_Test', element: 'Currency' } }]
CurrencyCode,
```

## 테스트 방법 메모
- 로컬 포워더(python, `adt_login` 세션)로 페이지와 `/sap/opu/*` 를 같은 origin 으로 서빙 → Playwright Chromium 에서 SmartFilterBar 실행, 나가는 OData 요청의 `$orderby` 로 판정.
- 게시 직후 `$metadata` 403(UCON)이 수 분 지속됨.
- SmartField 자동완성(typeahead)은 미검증. 다이얼로그는 위 (b) 방식으로 검증.
