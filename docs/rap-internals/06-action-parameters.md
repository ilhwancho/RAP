# 06. 액션 파라미터 (abstract entity / abstract BDEF)

## 요약 (실무용)
- 파라미터의 **특정 필드만 필수**로 하려면: `deep parameter` + abstract BDEF `field ( mandatory : execute )`.
- 이 검사는 **값이 아니라 "필드를 요청에 기재했는지"(존재 여부)** 만 본다.
  - OData: JSON 바디에 그 **키가 있는지**. `"Quantity": 0`, `"Remark": ""` 처럼 키만 있으면 통과.
  - EML: `%control-필드 = if_abap_behv=>mk-on` 인지. 값을 넣어도 `%control` 이 off 면 런타임 오류 (키워드 문서 예제).
- 값 조건(0 초과, 공백 불가 등)은 **액션 구현에서 직접** 검사하고 `failed` / `reported` 로 반환.
- flat `parameter` 에서는 `mandatory : execute` 가 **무시**되고, 대신 OData 에서 **모든 파라미터가 필수**가 된다.

## 문법 ✅ (키워드 문서 ABAP Cloud: `ABENBDL_FIELD_ABSTRACT`, `ABENBDL_ACTION_INPUT_PARAM`)
abstract BDEF 의 필드 특성은 두 가지뿐: `field ( suppress )`, `field ( mandatory : execute )`.
`mandatory : execute` 전제 조건 (모두 필요):
- CDS: `define root abstract entity ...`
- abstract BDEF 헤더: `abstract;` `strict ( 2 );` `with hierarchy;`
- 엔티티: `define behavior for ... with control`
- 액션: `deep parameter` 또는 `deep table parameter`
- `IN LOCAL MODE` 호출에는 효과 없음

```
" abstract BDEF
abstract;
strict ( 2 );
with hierarchy;
define behavior for ZD_CIH_SOActParam
with control
{
  field ( mandatory : execute ) Quantity;
}

" 본 BO BDEF
static action testDeepParam deep parameter ZD_CIH_SOActParam;
```
flat `parameter` 로 쓰면 활성화 경고: *The "parameter" type of "X" is not declared as "deep". Therefore, "..." is used as a flat type; its BDEF definition ("with hierarchy") is not used.*

## OData 실측 ✅ (2026-11-04, Z5U, Web API 바인딩 `ZAPI_CIH_SALESORDER_O4`)
시험 객체: `ZD_CIH_SOActParam`(Quantity quan(13,3), QuantityUnit, Remark), `ZR_CIH_SalesOrder` 의 시험용 static action
`testFlatParam`(flat) / `testDeepParam`(deep). 소스: `ABAP/ZCIH_SO_BO/`.

`$metadata` (액션 파라미터 어노테이션)
| | Quantity | 나머지 필드 |
|---|---|---|
| flat | (없음) | (없음) → OData 상 전부 필수 |
| deep, mandatory 없음 | `Core.OptionalParameter` | `Core.OptionalParameter` |
| deep, mandatory 있음 | `Common.FieldControl/Mandatory` | `Core.OptionalParameter` |

호출 결과
| 요청 바디 | flat | deep + mandatory |
|---|---|---|
| 전 필드 | 204 | 204 |
| Quantity 키 없음 | 400 | **400** `No value for mandatory parameter` |
| Remark 키만 없음 | **400** | 204 (초기값 전달) |
| `"Quantity": 0` | 204 | **204** (값 검사 안 함) |
| `"Quantity": null` | 400 (파싱: `Nullable=false`) | 400 (파싱) |

- 대조 시험: deep 에서 `mandatory : execute` 를 빼면 Quantity 생략도 204 → 400 은 `mandatory : execute` 효과.
- 거부는 Gateway(`/IWCOR/CX_OD_EP_PARAM_ERROR`)가 RAP 핸들러 도달 **전**에 한다. 덤프가 아니라 HTTP 400.
- abstract BDEF 변경 후 이를 쓰는 BO/프로젝션 BDEF 도 재활성화해야 메타데이터에 반영.
- Web API 바인딩 URL 은 `/srvd_a2x/` 경로.

## 하위 엔티티(composition) 필수: `association ( mandatory : execute )` ✅ (2026-11-05 실측, V4 Web API)
키워드 문서 `ABENBDL_ASSOCIATION_ABSTRACT`: composition·cross-BO association 에 가능, to-parent 불가. 전제 조건은 필드와 동일.
```
// CDS
define root abstract entity ZD_CIH_SOActParam { ...  _Item : composition [0..*] of ZD_CIH_SOActParamItem; }
define abstract entity ZD_CIH_SOActParamItem { ItemNo : abap.numc(6); ProductID : abap.char(40);
                                               _Header : association to parent ZD_CIH_SOActParam; }
// abstract BDEF
define behavior for ZD_CIH_SOActParam alias Header with control
{ field ( mandatory : execute ) Quantity;  association ( mandatory : execute ) _Item; }
define behavior for ZD_CIH_SOActParamItem alias Item with control
{ field ( mandatory : execute ) ProductID;  association _Header; }
```
`$metadata`: 액션 파라미터 `_Item` = `Collection(ZD_CIH_SOActParamItem)` + `FieldControl/Mandatory`,
아이템 complex type 의 `ProductID` = `FieldControl/Mandatory`.

| 요청 바디 (Quantity 는 포함) | 결과 |
|---|---|
| `_Item` 2건 (ProductID 포함) | 204 |
| `_Item` 키 없음 | **400** `/IWCOR/CX_OD_EP_PARAM_ERROR` `No value for mandatory parameter '_Item'` |
| `"_Item": []` | **204** (아이템 0건으로 전달) |
| `"_Item": null` | 400 `Property '_Item' is invalid` |
| 아이템에 ProductID 키 없음 / 2건 중 1건만 없음 / 빈 객체 `{}` | **400** `SADL_GW/053 ... Mandatory field PRODUCTID has not been provided` |
| 아이템 `"ProductID": ""` | **204** |
| 아이템 ItemNo 키 없음 | 204 |

- association 필수도 **키 존재 여부만** 검사 → 빈 배열 `[]` 통과. "최소 1건" 은 액션 구현에서 `lines( key-%param-_Item ) = 0` 검사 필요.
- 아이템 필드 필수 검사는 Gateway 가 아니라 **SADL 어댑터**(메시지 `SADL_GW/053`)가 수행, 아이템 하나라도 누락이면 400.

## 값 검증 예 (액션 구현)
```abap
LOOP AT keys INTO DATA(key).
  IF lines( key-%param-_Item ) = 0.          " 아이템 최소 1건 (빈 배열은 mandatory 를 통과함)
    APPEND VALUE #( %cid = key-%cid ) TO failed-salesorder.
    APPEND VALUE #( %cid = key-%cid
                    %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                  text     = '아이템을 1건 이상 입력하세요.' ) )
           TO reported-salesorder.
  ENDIF.
  IF key-%param-Quantity <= 0.
    APPEND VALUE #( %cid = key-%cid ) TO failed-salesorder.
    APPEND VALUE #( %cid = key-%cid
                    %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                  text     = 'Quantity는 0보다 커야 합니다.' ) )
           TO reported-salesorder.
  ENDIF.
ENDLOOP.
```

## 미확인 ⚠️
- OData V2 바인딩에서의 동작 (V2 바인딩 `ZAPI_CIH_SALESORDER_O2` 생성·활성화까지만 함, 게시·시험 미완)
- EML 에서 `%control` off 시 런타임 오류 (문서 기준, 미실측)
- UI(Fiori) 액션 팝업의 필수 표시 동작
