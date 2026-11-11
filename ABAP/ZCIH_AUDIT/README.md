# ZCIH_AUDIT — 감사필드 세팅 헬퍼 (미활성화, 레포 전용)

ABAP SQL 로 직접 쓰는 테이블(비-RAP)에 INSERT/UPDATE 할 때 감사필드를 채우는 클래스.
RAP managed BO 테이블은 대상 아님 — CDS 에 `@Semantics.user.createdBy` 등을 달면 프레임워크가 채운다
(분석: `docs/rap-internals/08-admin-fields.md`).

| 객체 | 설명 |
|---|---|
| `zs_cih_audit.tabl.asddls` | 감사 구조체 (created_by/at, changed_by/at) |
| `zcl_cih_audit.clas.abap` | 헬퍼. `create( )` 후 `set_for_insert` / `set_for_update` (+ `_single`) |
| `zcl_cih_audit.clas.testclasses.abap` | ABAP Unit (그룹명 없는 인클루드, UTCLONG/TIMESTAMP, 오류 케이스) |
| `zif_cih_audit_context.intf.abap` | 사용자/현재시각 제공 인터페이스 (테스트에서 교체) |
| `zcl_cih_audit_context.clas.abap` | 기본 구현 (`cl_abap_context_info=>get_user_technical_name( )`, `utclong_current( )`) |
| `zcx_cih_audit.clas.abap` | 오류 (감사필드 없음, 지원하지 않는 타입 등) |

## 테이블 쪽
그룹명(별칭) **없이** 인클루드하면 된다:
```abap
define table zat_cih_xxx {
  key client : abap.clnt not null;
  key id     : sysuuid_x16 not null;
  ...
  include zs_cih_audit;
}
```
인클루드 필드는 행 구조에 평평하게 펼쳐지므로 헬퍼는 필드 이름(`CREATED_BY`, `CREATED_AT`, `CHANGED_BY`, `CHANGED_AT`)으로 찾는다.
(그룹명을 붙여도 필드 이름은 그대로 접근되므로 동작한다. `WITH SUFFIX` 로 이름이 바뀐 경우는 지원하지 않음.)

## 사용
```abap
DATA(lo_audit) = zcl_cih_audit=>create( ).

lo_audit->set_for_insert( CHANGING ct_data = lt_new ).
INSERT zat_cih_xxx FROM TABLE @lt_new.

SELECT * FROM zat_cih_xxx WHERE ... INTO TABLE @DATA(lt_old).
" ... 수정 ...
lo_audit->set_for_update( CHANGING ct_data = lt_old ).
UPDATE zat_cih_xxx FROM TABLE @lt_old.
```

## 동작
- 행 타입을 한 번 분석(RTTI)해서 채울 필드와 타입을 정한다.
  - INSERT: 4개 필드 모두 필요. UPDATE: `CHANGED_*` 만 필요 (`CREATED_*` 는 건드리지 않음).
  - 필드가 없거나 타입이 맞지 않으면 `ZCX_CIH_AUDIT`.
- 사용자/시각은 **호출당 한 번** 구해 모든 행에 같은 값 (프레임워크와 동일).
- 시각 필드 타입에 맞춰 변환 (프레임워크 `CL_CSP_ACT_SET_ADMIN_DATA` 방식):
  `UTCLONG` 그대로 / `TIMESTAMPL`(p dec 7) `cl_abap_tstmp=>utclong2tstmp` / `TIMESTAMP`(p dec 0) `utclong2tstmp_short`.
- 사용자 필드는 문자(`C`)/`STRING` 타입만 허용.

## 주의
- `UPDATE dbtab FROM wa` 는 모든 컬럼을 덮어쓴다 → 새로 만든 구조체로 UPDATE 하면 `created_*` 가 비워진다.
  기존 행을 읽어 고치거나 `UPDATE ... SET changed_by = ..., changed_at = ...` 사용.
  (프레임워크는 `%control` 플래그로 관리 필드 컬럼만 partial update 에 추가해 이 문제를 피한다.)
- `MODIFY` 는 INSERT/UPDATE 를 구분할 수 없으므로 감사필드 테이블에는 피한다.
- 부모 테이블의 changed 갱신(프레임워크의 조상 전파)은 하지 않는다.
- 아직 Z5U 에서 문법 체크·활성화·유닛 테스트 실행을 하지 않았다.
