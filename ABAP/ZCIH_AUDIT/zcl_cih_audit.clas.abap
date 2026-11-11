"! <p class="shorttext synchronized">감사필드(ZS_CIH_AUDIT) 세팅 헬퍼</p>
"! 테이블은 감사 구조체를 그룹명 AUDIT 으로 인클루드해야 한다:
"!   audit : include zs_cih_audit;
"! 이 클래스는 값만 채운다. INSERT/UPDATE 는 호출하는 쪽에서 한다.
"! RAP managed BO 테이블은 대상 아님 (CDS @Semantics.user/systemDateTime 로 프레임워크가 채움).
CLASS zcl_cih_audit DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CONSTANTS c_group TYPE string VALUE 'AUDIT'.

    "! INSERT 전: created_* 와 changed_* 세팅
    CLASS-METHODS set_for_insert
      CHANGING ct_data TYPE STANDARD TABLE
      RAISING  cx_sy_assign_error.

    "! UPDATE 전: changed_* 만 세팅 (created_* 는 유지)
    "! 주의: UPDATE dbtab FROM wa 는 모든 컬럼을 덮어쓰므로, 기존 행을 읽어 고친 데이터에 써야 한다.
    CLASS-METHODS set_for_update
      CHANGING ct_data TYPE STANDARD TABLE
      RAISING  cx_sy_assign_error.

    "! 한 건(구조체) 버전
    CLASS-METHODS set_for_insert_single
      CHANGING cs_data TYPE any
      RAISING  cx_sy_assign_error.

    CLASS-METHODS set_for_update_single
      CHANGING cs_data TYPE any
      RAISING  cx_sy_assign_error.

  PRIVATE SECTION.
    CLASS-METHODS stamp_row
      IMPORTING iv_insert TYPE abap_bool
                iv_user   TYPE abp_creation_user
                iv_now    TYPE abp_creation_tstmpl
      CHANGING  cs_row    TYPE any
      RAISING   cx_sy_assign_error.

    CLASS-METHODS stamp_table
      IMPORTING iv_insert TYPE abap_bool
      CHANGING  ct_data   TYPE STANDARD TABLE
      RAISING   cx_sy_assign_error.
ENDCLASS.


CLASS zcl_cih_audit IMPLEMENTATION.

  METHOD set_for_insert.
    stamp_table( EXPORTING iv_insert = abap_true CHANGING ct_data = ct_data ).
  ENDMETHOD.

  METHOD set_for_update.
    stamp_table( EXPORTING iv_insert = abap_false CHANGING ct_data = ct_data ).
  ENDMETHOD.

  METHOD set_for_insert_single.
    DATA lv_now TYPE abp_creation_tstmpl.
    GET TIME STAMP FIELD lv_now.
    stamp_row( EXPORTING iv_insert = abap_true
                         iv_user   = cl_abap_context_info=>get_user_technical_name( )
                         iv_now    = lv_now
               CHANGING  cs_row    = cs_data ).
  ENDMETHOD.

  METHOD set_for_update_single.
    DATA lv_now TYPE abp_creation_tstmpl.
    GET TIME STAMP FIELD lv_now.
    stamp_row( EXPORTING iv_insert = abap_false
                         iv_user   = cl_abap_context_info=>get_user_technical_name( )
                         iv_now    = lv_now
               CHANGING  cs_row    = cs_data ).
  ENDMETHOD.

  METHOD stamp_table.
    " 한 번만 계산 → 같은 호출의 모든 행이 같은 사용자/시각
    DATA lv_now TYPE abp_creation_tstmpl.
    GET TIME STAMP FIELD lv_now.
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<row>).
      stamp_row( EXPORTING iv_insert = iv_insert
                           iv_user   = CONV #( lv_user )
                           iv_now    = lv_now
                 CHANGING  cs_row    = <row> ).
    ENDLOOP.
  ENDMETHOD.

  METHOD stamp_row.
    FIELD-SYMBOLS <audit> TYPE zs_cih_audit.

    ASSIGN COMPONENT c_group OF STRUCTURE cs_row TO <audit>.
    IF sy-subrc <> 0.
      " 감사 구조체를 그룹명 AUDIT 으로 인클루드하지 않은 테이블 → 개발 오류
      RAISE EXCEPTION NEW cx_sy_assign_error( ).
    ENDIF.

    IF iv_insert = abap_true.
      <audit>-created_by = iv_user.
      <audit>-created_at = iv_now.
    ENDIF.
    <audit>-changed_by = iv_user.
    <audit>-changed_at = iv_now.
  ENDMETHOD.

ENDCLASS.
