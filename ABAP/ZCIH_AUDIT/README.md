# ZCIH_AUDIT — 감사필드 세팅 헬퍼 (미활성화, 레포 전용)

ABAP SQL 로 직접 쓰는 테이블(비-RAP)에 INSERT/UPDATE 할 때 감사필드를 채우는 클래스.
RAP managed BO 테이블은 대상 아님 — CDS 에 `@Semantics.user.createdBy` 등을 달면 프레임워크가 채운다.

| 객체 | 설명 |
|---|---|
| `zs_cih_audit.tabl.asddls` | 감사 구조체 (created_by/at, changed_by/at — TIMESTAMPL) |
| `zcl_cih_audit.clas.abap` | `set_for_insert` / `set_for_update` (+ `_single`) |

## 테이블 쪽
감사 구조체를 **그룹명 `audit`** 으로 인클루드 (DDIC DDL `[group :] INCLUDE struct`, 키워드 문서 `ABENDDICDDL_DEFINE_TABLE_INCL`):
```abap
define table zat_cih_xxx {
  key client : abap.clnt not null;
  key id     : sysuuid_x16 not null;
  ...
  audit      : include zs_cih_audit;
}
```
DB 컬럼은 평평하게 펼쳐지고, ABAP 에선 `ls_row-audit` 를 `zs_cih_audit` 구조체로 다룰 수 있다.

## 사용
```abap
zcl_cih_audit=>set_for_insert( CHANGING ct_data = lt_new ).
INSERT zat_cih_xxx FROM TABLE @lt_new.

SELECT * FROM zat_cih_xxx WHERE ... INTO TABLE @DATA(lt_old).
" ... 수정 ...
zcl_cih_audit=>set_for_update( CHANGING ct_data = lt_old ).
UPDATE zat_cih_xxx FROM TABLE @lt_old.
```

## 주의
- ABAP Cloud 시스템 필드 목록에 `sy-datum`/`sy-uzeit` 없음 (`sy-uname` 은 있음). 사용자는 `cl_abap_context_info=>get_user_technical_name( )`, 시각은 `GET TIME STAMP FIELD`.
- `UPDATE dbtab FROM wa` 는 모든 컬럼을 덮어쓴다 → 새로 만든 구조체로 UPDATE 하면 `created_*` 가 비워진다. 기존 행을 읽어 고치거나 `UPDATE ... SET changed_by = ..., changed_at = ...` 사용.
- `MODIFY` 는 INSERT/UPDATE 를 구분할 수 없으므로 감사필드 테이블에는 피한다.
- 유닛 테스트에서 사용자/시각을 고정하려면 인스턴스 클래스 + 컨텍스트 인터페이스 주입으로 바꾼다 (`docs/rap-internals/07-unit-testing.md` 방식 A').
