# CDS view entity – 식 재사용(`$projection`)과 association ON 조건

2026-11-09 세션 정리 (Z5U, AS ABAP Release 920, ABAP for Cloud Development 문서 기준).
표기: ✅ 문서/시스템으로 확인, ⚠️ 추정.

## 1. 식 재사용 (reuse expression) — ✅ 문서 `ABENCDS_REUSABLE_EXPRESSION_V2`
SELECT 리스트에서 별칭을 붙인 요소를 같은 뷰 안에서 `$projection.<별칭>` 으로 다시 쓴다.

- 사용 위치: **SELECT 리스트**(식의 일부), **association ON 조건**
- 재사용 가능한 식: 필드, 리터럴, 산술식, cast, 내장 함수, SQL 스칼라 함수, case, 경로식
- 제약
  - 순환 참조 금지 (x→z→y→x 는 문법 오류)
  - **WHERE / GROUP BY / HAVING / 필터 조건에서는 불가** (문서 표현 "currently")
  - 파라미터·세션 변수·집계 함수가 들어간 요소는 재사용 불가
  - 금액/수량 필드를 재사용하면 통화/단위 참조 정보가 사라짐 (calculated quantity 는 성격은 유지, 참조는 다시 지정해야 함)

## 2. 재사용은 인라인 치환이다 — ✅ 생성 SQL 확인
`$projection.x` 는 별칭(컬럼)을 참조하지 않는다. 컴파일러가 **원래 식을 그 자리에 그대로 복사**한다.
`python tools/adt/cds_view.py DEMO_CDS_EXPRESSION_REUSE --sql` 결과 일부:

| CDS | HANA SQL |
|---|---|
| `$projection.arith * 2 as arith_reuse` | `CAST( (CAST( 123.45E6 AS DECIMAL ) * 2) AS DECIMAL ) AS "ARITH_REUSE"` |
| `left($projection.case1, 1) as case_reuse` | `RTRIM( LEFT( RTRIM( CASE "DEMO_EXPRESSIONS"."CHAR2" WHEN ... END ), 1 )) AS "CASE_REUSE"` |

배경: SQL 논리 처리 순서는 `FROM/JOIN(ON) → WHERE → GROUP BY → HAVING → SELECT` 이다.
SELECT 의 별칭은 그 SELECT 안에서도, 앞 단계(ON/WHERE…)에서도 아직 없으므로 인라인할 수밖에 없다.
WHERE/GROUP BY/HAVING 에서 재사용이 막힌 것도 같은 맥락으로 이해된다 (⚠️ SAP 가 이유를 명시하지는 않음).

## 3. ON 조건에 식 별칭을 쓴 association — ✅ 문법 체크(check run) 시험
```abap
association [0..1] to zat_cih_soh as _H on $projection.ProdKey = _H.customer_id
...
left(product_id, 10) as ProdKey,
```
| 케이스 | SELECT 리스트 | 결과 |
|---|---|---|
| A | `_H.description` (같은 뷰에서 경로식 사용) | ❌ `SDDL_PARSER_MSG 061` "association cannot be used locally in the view" |
| B | `_H` (노출만) | ✅ 통과 |
| C | `_H.description` + `_H` | ❌ A 와 같은 오류 |
| 비교 | ON 이 일반 필드 별칭(`$projection.CurrencyCode`) + `_H.description` | ✅ 통과 |

### 원인
1. 같은 뷰에서 association 필드를 읽으면 association 이 **로컬 JOIN 으로 변환**되고, ON 조건이 JOIN ON 에 그대로 들어간다
   (메시지 061 장문). → `ON left(zat_cih_soi.product_id, 10) = _H.customer_id` 형태 (⚠️ 활성화가 안 되므로 SQL 로 직접 확인은 불가, 2절 동작과 장문으로 추론).
2. view entity 의 **JOIN ON 규칙**(`ABENCDS_JOINED_DATA_SOURCE_V2`): lhs 는 필드(비교 연산자면 리터럴도), rhs 는 필드·리터럴·파라미터·세션 변수·내장 함수·스칼라 함수. 경로식과 그 밖의 CDS 식은 불가.
   061 장문도 `$projection` 이 가리키는 **경로식 / 계산 필드 / CAST·CASE·함수 호출**을 금지 대상으로 든다.
3. 즉 직접 원인은 처리 순서가 아니라 **CDS JOIN ON 문법 제약**이다. HANA SQL 자체는 ON 에 식을 허용한다.
   처리 순서는 "왜 인라인되는가" 를 설명한다.

### 케이스 B 가 되는 이유
노출된 association 은 **소비 뷰**에서 JOIN 으로 바뀐다. 그때 `ProdKey` 는 베이스 뷰가 이미 계산한 **결과 컬럼**이므로
ON 이 `ZR_Base.ProdKey = _H.customer_id` (필드 = 필드) 가 되어 규칙을 통과한다. → 상위 뷰에서 `_H.description` 을 읽으면 된다.
(⚠️ 소비 뷰의 실제 활성화/조회는 미시험)

### 문서와 다른 점
`ABENCDS_SIMPLE_ASSOCIATION_V2` 는 "`$projection` 이 경로식·리터럴·식을 가리키면 association 을 노출할 수 없다" 고 쓰지만,
Release 920 체크에서는 **노출(B)은 통과**하고 **로컬 사용(A)만 오류**였다.

### 우회
- association 은 노출만 하고 상위 뷰에서 필드를 읽는다 (B).
- 식을 베이스 뷰에서 계산해 두고 그 위 뷰에서 association 을 정의한다.

## 4. 이번에 쓴 도구
- 생성 SQL 보기: `python tools/adt/cds_view.py <CDS> --sql` (`POST /sap/bc/adt/ddic/ddl/createstatements/{name}`, 활성 버전)
- 저장하지 않는 문법 체크: `docs/adt-object-deploy.md` 의 "저장 없이 문법 체크" 참조
- 메시지 장문: check run 결과의 `atom:link rel=".../longtext"` (`/sap/bc/adt/messageclass/{클래스}/messages/{번호}/longtext?msgv1=...`)
