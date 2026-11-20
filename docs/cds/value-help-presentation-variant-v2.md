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
- 읽기 전용 서비스에서 `createEntry` 로 SmartField 를 편집 모드로 띄우는 건 실패(표시 모드) → SmartField 자동완성은 미검증, SmartFilterBar 로 판정.
