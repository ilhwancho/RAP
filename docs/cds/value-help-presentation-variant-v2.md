# 값 도움말 정렬: UI.presentationVariant (OData V2)

2026-11-20 실측. Z5U(Release 920), SAPUI5 1.154 (`sap.ui.comp`, ui5.sap.com).
테스트 객체: 패키지 `ZCIH_VH_TEST` (`ABAP/ZCIH_VH_TEST/`), 바인딩 `ZUI_CIH_SOVHTEST_O2` (V2 UI).
- 시스템의 테스트 CDS 마지막 상태: VH PV `#SortDesc`(Decimals desc) + 소비 쪽 `presentationVariantQualifier: 'SortDesc'` → V4 정상, **V2 바인딩 값 도움말은 깨진 상태**(A 경우).
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

## qualifier 를 넣으면 V2 값 도움말이 깨지는 이유 (UI5 1.154 소스)
1. `MetadataAnalyser.getValueListAnnotationLazy` (MetadataAnalyser-dbg.js ~1748–1766, 함수용 ~1896–1910):
   ValueList 에 `PresentationVariantQualifier` 가 있으면 `primaryValueListAnnotation` 이 아니라 `primaryValueListAnnotationWithPVQualifier` 에 넣는다
   (소스 주석 "TODO: to be removed in the next release! - Ignore ValueList with PresentationVariantQualifier").
2. `BaseValueListProvider._onAnnotationLoad` (~248–281): 첫 줄에서 `this.oPrimaryValueListAnnotation = mValueList.primaryValueListAnnotation` (= undefined) 으로
   상태를 잡고 `_resolveAnnotationData(undefined)`. 그 아래에서 WithPVQualifier 를 합치긴 하지만 **지역 변수 `oAnnotation` 에만** 합쳐서 return → 프로바이더 상태엔 반영 안 됨.
   → `sValueListEntitySetName` 이 비어 `ValueListProvider - Empty sValueListEntitySetName ... (missing primaryValueListAnnotation)`, 요청 `GET .../null?$filter=startswith(undefined,E)` 404.
3. SmartField: `ODataHelper.loadValueListAnnotation` → 같은 `getValueListAnnotationLazy` 결과를 받은 `ODataControlFactory._initValueList` (~385–393) 가
   `oValueListAnnotations.primaryValueListAnnotation`(undefined) 을 `ODataHelper.getODataValueListKeyProperty` (~1068) 에 넘기고 거기서 `.fields` 접근 → `TypeError ... reading 'fields'`.

## 다이얼로그가 PV 를 읽고도 정렬 안 하는 이유 (UI5 1.154 소스 + 런타임 확인)
1.154 다이얼로그 테이블은 `ValueHelpDialog._createDefaultSFBSmartTable` 이 만드는 **내부 SmartTable**(`…-valueHelpDialog-table`).
`ValueHelpProvider._rebindTable` 은 이 테이블이 `isInternal` 이면 바로 return 하므로 정렬은 SmartTable 쪽에서 결정된다.

1. SmartTable 의 `TableProvider` 는 PV 를 **읽는다**. qualifier 는 SmartTable custom data `presentationVariantQualifier` 에서 가져오는데 VHD 는 안 넣음 → **qualifier 없는 PV 만** 대상.
   (ValueList 의 `PresentationVariantQualifier` 도 전달 안 됨 → qualified PV 는 다이얼로그에서 아예 안 읽힘)
2. 읽은 PV 는 필드 메타 `sorted/sortOrder` → 컬럼 sortOrder → `_aInitialSorters` 까지 들어간다.
   런타임: `_aInitialSorters = [{columnKey:"Decimals", operation:"Descending"}]`, Decimals 컬럼 `Descending`.
3. 그런데 `SmartTable._reBindTable` 의 sorter 는 `_getTablePersonalisationData()` 에서만 나오고, 이 함수는 **`_oCurrentVariant` 가 없으면 `null` 반환**.
   `_oCurrentVariant` 는 variant management 초기화(`_variantInitialised` → `"STANDARD"`)나 개인화 이벤트에서만 세팅되는데,
   VHD 는 SmartTable 을 `showVariantManagement: false, showTablePersonalisation: false` 로 만든다 → 계속 `undefined` → `_aInitialSorters` 가 안 쓰임.
   런타임: `beforeRebindTable` 시점 `bindingParams.sorter = []`, `_oCurrentVariant = undefined`, `personalisationData = null`.
4. VHD 의 `beforeRebindTable` 핸들러는 **sorter 가 비어 있고 basic search 값이 없으면** 키 sorter(`new Sorter(oConfig.key)`) 를 추가 → `$orderby=Currency asc`.
5. 인과 확인: 다이얼로그 연 뒤 `_oCurrentVariant = "STANDARD"` 만 넣고 `rebindTable()` → sorter `Decimals desc`, 행 BHD, IQD, JOD…, Go 후에도 유지.
   (private 필드 조작이라 해결책으로 쓰진 말 것. 원인 확인용.)

→ 정리: PV 정렬이 "초기 정렬값"으로는 계산되지만, 그 값을 바인딩에 쓰는 경로가 variant management 를 전제로 하고 있어 VHD 의 SmartTable 에서는 끊긴다.
   내부 SmartTable 이 없는 경로(`ValueHelpProvider._rebindTable` 이 직접 바인딩)는 원래 PV 를 보지 않고 키로만 정렬.

## OData V4 비교 (Fiori Elements V4 List Report, UI5 1.154)
같은 서비스 정의에 V4 UI 바인딩 `ZUI_CIH_SOVHTEST_O4` 추가. V4 는 값 도움말 메타데이터를 별도 문서(`srvd_f4/...`, `Common.ValueListReferences`)로 내보내고, 거기 `Common.ValueListMapping` 에 `PresentationVariantQualifier` 가 들어간다.

| 경우 | 자동완성 | 다이얼로그 |
|---|---|---|
| (ii) PV qualifier 없음, 소비 쪽 qualifier 미지정 | `$orderby=Decimals desc` | `$orderby=Decimals desc` (BHD, IQD… 먼저) |
| (i) PV `#SortDesc`, 소비 쪽 `presentationVariantQualifier: 'SortDesc'` | `$orderby=Decimals desc` | `$orderby=Decimals desc` |

→ V4 는 어노테이션만으로 자동완성·다이얼로그 모두 정렬됨. (i) 은 V2 에서 값 도움말을 깨뜨리는 조합인데 V4 에서는 정상, PV 가 qualified 하나뿐이므로 qualifier 로 찾는 것도 확인.
V4 Object Page 필드, 다른 UI5 버전은 미검증.

## 기타 배경
- 백엔드는 정상: `$metadata` 의 `Common.ValueList` 에 `PresentationVariantQualifier` 가 나가고(`CL_SADL_GW_VOCAN_EXPOSURE`),
  `UI.PresentationVariant#SortDesc` 는 V2 별도 주석 파일(`/sap/opu/odata/IWFND/CATALOGSERVICE;v=2/Annotations(TechnicalName='<바인딩>_VAN',Version='0001')/$value`)에 나간다.
- UI5 `MetadataAnalyser` 는 qualifier 가 없는(primary) ValueList 라도 `PresentationVariantQualifier` 가 있으면 `primaryValueListAnnotationWithPVQualifier` 로 따로 분류한다(소스 주석: "TODO … Ignore ValueList with PresentationVariantQualifier").
  `ODataControlFactory`·`ValueListProvider` 는 `primaryValueListAnnotation` 만 보므로 VH 가 없는 것처럼 동작해 깨진다.
- PV 정렬은 `ValueListProvider._handlePresentationVariantSortOrderAnnotation` 이 VH 엔티티 타입의 `UI.PresentationVariant#<q>` 를 직접 찾아서 쓴다(ValueList 의 qualifier 는 안 씀). 드롭다운 템플릿에서만 sorter 를 쓰고, sortOrder 첫 항목만 쓴다.
- 다이얼로그는 위 절 참고 (내부 SmartTable 경로에서 PV 초기 정렬이 끊기고 키 오름차순만 남음).

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
