# 밸류헬프 메타데이터 생성 (`@Consumption.valueHelpDefinition` → `Common.ValueList`)

RAP OData V4 UI 서비스에서 밸류헬프 어노테이션이 어떤 `ValueListParameter*` 로 바뀌는지.
분석: 2026-11-13, Z5U.

## 구조 ✅
- 메인 `$metadata` 에는 `Common.ValueListReferences` (VH 서비스 상대 URL) 만 나온다.
  실제 `Common.ValueList`(Parameters) 는 `../../../../srvd_f4/sap/<vh뷰>/0001;ps='srvd-<srvd>-0001';va='...'/$metadata` 에 있다.
  - 이 세션 환경의 프록시는 경로에 `;` 가 있으면 403 (`path contains matrix parameter separator`) → Claude 세션에서는 VH 메타데이터를 직접 못 받는다.
  - `;` 없이 `srvd_f4/.../$metadata` 를 부르면 SAP 가 `/IWBEP/CM_V4_COS/136 ... not assigned to group` 403.
- 파라미터 계산: `CL_SADL_GW_V4_MODEL_VH_MAP` (`_get_vh_inout_parameter`, `_set_src_elem_trg_elem_inout`, `_get_vh_display_param`, `_get_vh_default_binding`)
- 레코드 출력: `CL_SADL_GW_V4_VH_MAP_BUILDER` (InOut → In → Out → DisplayOnly → Constant 순)

## additionalBinding usage → 파라미터 ✅ (`_set_src_elem_trg_elem_inout`)
| usage | 생성 레코드 |
|---|---|
| (없음) / `#FILTER_AND_RESULT` | `ValueListParameterInOut` |
| `#FILTER` | `ValueListParameterIn` |
| `#FILTER_AND_DISPLAY` | `ValueListParameterIn` **+ `ValueListParameterDisplayOnly`** |
| `#RESULT` | `ValueListParameterOut` |
| `localConstant` + `#FILTER`/`#FILTER_AND_DISPLAY` | `ValueListParameterConstant` (`_get_vh_const_parameter`) |

## DisplayOnly 결정 규칙 ✅ (`_get_vh_display_param`)
VH 뷰의 각 요소에 대해:
- `@Consumption.hidden: true` / `@UI.hidden: true` → 제외
- 이미 InOut / Out 이면 → 제외 (InOut·Out 자체가 컬럼으로 보임)
- **In 이면 → 제외. 단 그 바인딩 usage 가 `#FILTER_AND_DISPLAY` 면 DisplayOnly 추가**
- VH 뷰에 `@Consumption.valueHelpDefault.display` 를 단 요소가 하나라도 있으면, `display: true` 인 요소만 DisplayOnly
- 나머지 → DisplayOnly

→ 필터용 바인딩(`#FILTER`) 필드가 VH 다이얼로그 컬럼에서 사라지는 원인. 컬럼을 유지하려면 `usage: #FILTER_AND_DISPLAY`.
예: `I_ProductPlantStdVH`(Product, Plant 뿐) 를 Product 에 걸고 Plant 를 `#FILTER` 로 바인딩하면 DisplayOnly 가 하나도 없다.

## 실측 객체
패키지 `ZCIH_VH_TEST` (`ABAP/ZCIH_VH_TEST/`): `ZC_CIH_VHTEST`(I_ProductPlantBasic, Product VH 에 Plant `#FILTER_AND_DISPLAY`),
`ZUI_CIH_VHTEST`, 바인딩 `ZUI_CIH_VHTEST_O4`. `#FILTER_AND_DISPLAY` 활성화 OK, 서비스 게시·조회 OK.
⚠️ VH 메타데이터·Fiori 다이얼로그 화면은 프록시 제약으로 Claude 가 직접 확인 못 함 (사용자 확인 필요).
