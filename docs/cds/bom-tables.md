# BOM 테이블 관계 (MAST / STKO / STAS / STPO) 와 ABAP Cloud released CDS

Z5U 시스템에서 확인 (2026-11-13). CDS 소스는 `tools/adt/cds_view.py <뷰> --source-only` 로 조회했고,
released 여부는 `ZCIH_SO_BO` 패키지 클래스의 check run(ABAP Cloud, 언어 버전 5) 결과로 판정했다.

## 1. 테이블 관계

```
MAST  자재 ↔ BOM 연결          키: MATNR, WERKS, STLAN, STLNR, STLAL
  │ STLNR + STLAL (STLTY = 'M' 고정 — MAST 에는 STLTY 컬럼이 없음)
  ▼
STKO  BOM 헤더 (대체 BOM별)     키: STLTY, STLNR, STLAL, STKOZ
  │ STLTY + STLNR + STLAL
  ▼
STAS  대체 BOM ↔ 아이템 선택    키: STLTY, STLNR, STLAL, STLKN, STASZ
  │ STLTY + STLNR + STLKN
  ▼
STPO  BOM 아이템               키: STLTY, STLNR, STLKN, STPOZ

STZU  BOM 영구 데이터 (STLTY + STLNR 단위: 용도 STLAN, 권한그룹, BOM 그룹, 이력 여부 등)
```

- **STPO 에는 STLAL 이 없다.** 아이템은 STLNR 단위로 저장되고 대체 BOM 들이 공유한다.
  아이템이 어느 대체 BOM 에 속하는지는 STAS 가 정한다 → STKO→STPO 직접 조인 금지, 반드시 STAS 경유.
- STLTY: `M` 자재, `E` 장비, `T` 기능위치, `D` 문서, `K` 판매오더, `S` 표준 BOM 등.
- STKOZ / STASZ / STPOZ: 내부 카운터. 변경번호(AENNR) 이력이 있으면 같은 키에 여러 건이 존재한다.
- 유효성: `DATUV`(시작) / `VALID_TO`(종료) 를 기준일과 비교. 삭제 표시는 `LKENZ`
  (STAS.LKENZ = 해당 대체 BOM 에서 그 아이템이 빠졌다는 뜻).
- 다단계 전개는 직접 조인 대신 표준 전개 로직 사용 (Classic: `CS_BOM_EXPL_MAT_V2`).

## 2. ABAP Cloud 에서의 사용 가능 여부 (check run 결과)

| 객체 | 결과 |
|---|---|
| MAST, STKO, STAS, STPO (테이블) | ❌ `The use of Table ... is not permitted` |
| I_MaterialBOM, I_BillOfMaterial, I_BillOfMaterialHeader, I_BillOfMaterialItem | ❌ `The use of CDS Entity ... is not permitted` |
| **I_MaterialBOMLink** | ✅ |
| **I_BillOfMaterialHeaderDEX_2** | ✅ |
| **I_BillOfMaterialItemDEX_3** | ✅ |
| **I_BillOfMaterialItemBasic** | ✅ |
| **I_BillOfMaterialTP_2 / I_BillOfMaterialItemTP_2** (RAP BO, EML 용) | ✅ |

## 3. 테이블 → released CDS 매핑

| 테이블 | released CDS | 실제 소스 |
|---|---|---|
| MAST | `I_MaterialBOMLink` | `select from mast`, `BillOfMaterialCategory = 'M'` 상수 |
| STKO (+STZU) | `I_BillOfMaterialHeaderDEX_2` | `P_BillOfMaterialHeaderDEX` = `stko inner join stzu on stlty, stlnr` |
| STAS + STPO | `I_BillOfMaterialItemDEX_3` | `P_BillOfMaterialItemDEX` = `stas inner join stpo on stlty, stlnr, stlkn and stas.lkenz = ' '` |
| STPO 단독 | `I_BillOfMaterialItemBasic` | `select from stpo` (대체 BOM 정보 없음 — STLAL 없음) |

→ **`I_BillOfMaterialItemDEX_3` 가 STAS 조인을 이미 해 둔 뷰**라서, 대체 BOM 별 아이템이 필요하면 이 뷰를 쓴다.
STAS 삭제 표시(LKENZ)도 뷰 안에서 걸러진다.

### 주요 필드 이름

| 테이블 필드 | CDS 필드 |
|---|---|
| STLTY | BillOfMaterialCategory |
| STLNR | BillOfMaterial |
| STLAL | BillOfMaterialVariant |
| STLAN | BillOfMaterialVariantUsage |
| MATNR / WERKS (MAST) | Material / Plant |
| STKOZ | BOMHeaderInternalChangeCount |
| STLKN | BillOfMaterialItemNodeNumber |
| STASZ | BOMInstceInternalChangeNumber |
| STPOZ | BOMItemInternalChangeCount |
| STKO-BMENG / BMEIN | BOMHeaderQuantityInBaseUnit / BOMHeaderBaseUnit |
| STKO-STLST | BillOfMaterialStatus |
| STKO-DATUV / VALID_TO | HeaderValidityStartDate / HeaderValidityEndDate |
| STKO-LKENZ | DeletionIndicator |
| STPO-POSNR | BillOfMaterialItemNumber |
| STPO-IDNRK | BillOfMaterialComponent |
| STPO-MENGE / MEINS | BillOfMaterialItemQuantity / BillOfMaterialItemUnit |
| STPO-POSTP | BillOfMaterialItemCategory |
| STPO-DATUV / VALID_TO | ValidityStartDate / ValidityEndDate |
| STPO-AENNR | EngineeringChangeDocument |

## 4. ABAP Cloud 조회 예시 (check run 통과 확인)

MAST → STKO → STAS → STPO 조인을 released 뷰로 바꾼 것:

```abap
DATA(lv_date) = cl_abap_context_info=>get_system_date( ).

SELECT FROM i_materialbomlink AS link                       " MAST
  INNER JOIN i_billofmaterialheaderdex_2 AS hdr               " STKO (+STZU)
    ON  hdr~billofmaterialcategory = link~billofmaterialcategory
    AND hdr~billofmaterial         = link~billofmaterial
    AND hdr~billofmaterialvariant  = link~billofmaterialvariant
  INNER JOIN i_billofmaterialitemdex_3 AS itm                 " STAS + STPO
    ON  itm~billofmaterialcategory = hdr~billofmaterialcategory
    AND itm~billofmaterial         = hdr~billofmaterial
    AND itm~billofmaterialvariant  = hdr~billofmaterialvariant
  FIELDS link~material, link~plant, link~billofmaterialvariantusage,
         link~billofmaterial, link~billofmaterialvariant,
         hdr~bomheaderquantityinbaseunit, hdr~bomheaderbaseunit,
         itm~billofmaterialitemnumber, itm~billofmaterialcomponent,
         itm~billofmaterialitemquantity, itm~billofmaterialitemunit,
         itm~billofmaterialitemcategory
  WHERE link~plant = '1010'
    AND hdr~deletionindicator = @abap_false
    AND hdr~headervaliditystartdate <= @lv_date
    AND hdr~headervalidityenddate   >  @lv_date
    AND itm~validitystartdate <= @lv_date
    AND itm~validityenddate   >  @lv_date
  ORDER BY link~material, link~billofmaterialvariant, itm~billofmaterialitemnumber
  INTO TABLE @DATA(lt_bom).
```

- 플랜트 `'1010'` 은 예시 값이다. 실제 데이터로 실행해 보지는 않았다 (문법 체크만 통과 확인).
- 변경번호 이력이 있는 BOM 은 같은 키에 여러 버전이 있으므로 유효일 조건이 필요하다.
  `VALID_TO` 가 비어 있는 행이 있을 수 있는데, `I_BillOfMaterialItemBasic` 은 이 경우를 CASE 로 보정한다.
  DEX 뷰에서 종료일 조건으로 빠지는 행이 있으면 이 점을 확인할 것.
- 생성·변경은 SELECT 가 아니라 RAP BO `I_BillOfMaterialTP_2` (자식 `I_BillOfMaterialItemTP_2`,
  손자 `I_BillOfMaterialSubItemTP_2`) 에 EML 로 한다.
  루트 키: BillOfMaterial, BillOfMaterialCategory, BillOfMaterialVariant, BillOfMaterialVersion,
  EngineeringChangeDocument, Material, Plant.
