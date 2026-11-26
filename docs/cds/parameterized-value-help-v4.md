# 파라미터 CDS 를 값 도움말(VH)로 쓰기 — Fiori Elements V4 실측 (2026-11-26)

결론: **FE V4 (UI5 1.154) 필터바 값 도움말에서 파라미터 CDS VH 는 동작하지 않는다.** 바인딩 방식(상수·로컬 요소·시스템 필드·바인딩 없음)과 무관하게
다이얼로그는 열리지만(열 헤더만) **데이터 요청이 아예 나가지 않는다.** 자동완성도 요청 없음.

## 테스트 구성 (패키지 `ZCIH_VH_TEST`, 바인딩 `ZUI_CIH_SOVHTEST_O4`)
- `ZI_CIH_CurrVHParam` : `with parameters P_MinDecimals : int1`, `I_Currency` 중 `Decimals >= P_MinDecimals`
- `ZI_CIH_CurrVHSys` : `@Environment.systemField: #SYSTEM_LANGUAGE P_Language : spras`, `I_CurrencyText` 중 해당 언어
- `ZC_CIH_SOVHTest` 에 `CurrencyCode` 별칭 필터 필드 추가 (서비스 정의에 두 VH expose)

| 필드 | valueHelpDefinition | V4 F4 메타데이터 `ValueListMapping` | 다이얼로그 |
|---|---|---|---|
| `CurrencyCode` (기준) | 파라미터 없는 `ZI_CIH_CurrencyVH_Test` | `CollectionPath="ZI_CIH_CurrencyVH_Test"` | 요청·데이터 정상 |
| `CurrConst` | `additionalBinding: [{ parameter: 'P_MinDecimals', localConstant: '3' }]` | `CollectionPath="ZI_CIH_CurrVHParam/Set"`, **상수 바인딩이 매핑에 없음** | 요청 없음 |
| `CurrElem` | `{ parameter: 'P_MinDecimals', localElement: 'MinDecimals' }` | 위 + `ValueListParameterInOut` `LocalDataProperty=MinDecimals` / `ValueListProperty="ParametersxP_MinDecimals"` (VH 타입에 없는 이름 → 다이얼로그에 열로 나옴) | 요청 없음 (MinDecimals=3 입력 후에도) |
| `CurrSys` | 바인딩 없음, VH 파라미터가 `@Environment.systemField` | `CollectionPath="ZI_CIH_CurrVHSys/Set"` | 요청 없음 |
| `CurrNone` | 바인딩 없음, 일반 파라미터 | `CollectionPath="ZI_CIH_CurrVHParam/Set"` | 요청 없음 |

## 원인
- V4 에서 파라미터 뷰는 `EntitySet ZI_X`(타입 `..Parameters`, 키 = 파라미터) → containment 내비 `Set` 로 노출. 데이터 URL 은 `ZI_X(P_...=값)/Set` 형태여야 한다.
- SADL 이 만드는 `CollectionPath` 는 키 없는 `ZI_X/Set`. 서버에 그대로 보내면 400 `Invalid key predicate. Value 'Set' for key property 'P_M...'`.
  `ZI_CIH_CurrVHParam(P_MinDecimals=3)/Set`, `ZI_CIH_CurrVHSys(P_Language='EN')/Set` 처럼 키를 주면 F4 서비스·메인 서비스 모두 200.
  → 시스템 필드 파라미터도 OData V4 에서는 URL 키로 줘야 하며 서버가 자동으로 채우지 않는다.
- sap.fe (1.154) 다이얼로그 테이블 payload `collectionName: "ZI_CIH_CurrVHParam/Set"`, **row binding 이 생성되지 않음** (기준 필드는 `/ZI_CIH_CurrencyVH_Test`).
  sap.fe.macros / sap.fe.core library-preload 에 `Parametersx…` 나 파라미터 VH 키를 채우는 처리 없음 (`bindList("/"+CollectionPath)` 만).

## 대안 (⚠️ 미실측)
- VH 뷰에서 파라미터를 없앤다.
  - 시스템 값: WHERE 에 `$session.system_language`, `$session.system_date` 등.
  - 호출 쪽 값으로 거르기: 파라미터 대신 VH 의 일반 필드로 만들고 `additionalBinding: [{ element: 'Decimals', localConstant: '3', usage: #FILTER }]` 또는 `localElement` (→ `ValueListParameterConstant` / `ValueListParameterIn`).

## 그 밖의 발견
- 파라미터를 `abap.int1`(내장 타입), 소비 뷰에 `cast( 0 as abap.int1 )` 을 쓴 상태에서 V4 `$metadata` 가 500 덤프 (`RAISE_EXCEPTION` in `CL_ABAP_TYPEDESCR`,
  호출 `CL_SADL_GW_V4_PROPERTY_BUILDER` → `describe_by_name( property->get_ddic_element( ) )`). 둘 다 데이터 요소 `int1` 로 바꾸니 정상.
  ⚠️ 파라미터·cast 중 어느 쪽이 원인인지는 분리 안 함. `currdec_cds` 는 ABAP Cloud 에서 사용 불가(미릴리스).
- V2 바인딩(`ZUI_CIH_SOVHTEST_O2`) 동작은 미검증. Object Page 편집 필드도 미검증.

## 재현
`tools/ui5-vh-test/go6.sh [스크린샷폴더]` (`run6.js`: 각 필터 필드 다이얼로그를 열어 요청·행 출력)
