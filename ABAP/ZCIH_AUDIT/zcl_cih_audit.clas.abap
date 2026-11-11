"! <p class="shorttext synchronized">감사필드(ZS_CIH_AUDIT) 세팅 헬퍼</p>
"! 테이블에 ZS_CIH_AUDIT 를 인클루드하면 된다 (그룹명 없어도 됨):
"!   include zs_cih_audit;
"! 필드 이름/타입은 문자열 상수가 아니라 <strong>ZS_CIH_AUDIT 구조체에서</strong> 가져온다:
"! - 검사: RTTI 로 ZS_CIH_AUDIT 의 컴포넌트 목록을 읽어, 행 타입에 같은 이름·같은 타입 필드가 있는지 확인
"! - 값 세팅: ZS_CIH_AUDIT 타입 작업영역을 채운 뒤 MOVE-CORRESPONDING 으로 행에 복사
"!   (ls_audit-created_by 처럼 정적 접근 → 구조체 필드명이 바뀌면 문법 오류로 바로 드러남)
"! 이 클래스는 값만 채운다. INSERT/UPDATE 는 호출하는 쪽에서 한다.
"! RAP managed BO 테이블은 대상 아님 (CDS @Semantics.user/systemDateTime 로 프레임워크가 채움,
"! docs/rap-internals/08-admin-fields.md).
CLASS zcl_cih_audit DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! @parameter io_context | 생략하면 ZCL_CIH_AUDIT_CONTEXT (현재 사용자, utclong_current)
    CLASS-METHODS create
      IMPORTING io_context      TYPE REF TO zif_cih_audit_context OPTIONAL
      RETURNING VALUE(ro_audit) TYPE REF TO zcl_cih_audit.

    "! INSERT 전: 감사필드 전부(created_* + changed_*) 세팅
    METHODS set_for_insert
      CHANGING ct_data TYPE STANDARD TABLE
      RAISING  zcx_cih_audit.

    "! UPDATE 전: changed_* 만 세팅 (created_* 는 행의 기존 값 유지)
    "! 주의: UPDATE dbtab FROM wa 는 모든 컬럼을 덮어쓴다 → 기존 행을 읽어 고친 데이터에 쓸 것.
    METHODS set_for_update
      CHANGING ct_data TYPE STANDARD TABLE
      RAISING  zcx_cih_audit.

    METHODS set_for_insert_single
      CHANGING cs_data TYPE any
      RAISING  zcx_cih_audit.

    METHODS set_for_update_single
      CHANGING cs_data TYPE any
      RAISING  zcx_cih_audit.

  PRIVATE SECTION.
    DATA mo_context TYPE REF TO zif_cih_audit_context.

    METHODS constructor
      IMPORTING io_context TYPE REF TO zif_cih_audit_context.

    METHODS stamp_table
      IMPORTING iv_insert TYPE abap_bool
      CHANGING  ct_data   TYPE STANDARD TABLE
      RAISING   zcx_cih_audit.

    METHODS stamp_single
      IMPORTING iv_insert TYPE abap_bool
      CHANGING  cs_data   TYPE any
      RAISING   zcx_cih_audit.

    "! 행 타입이 ZS_CIH_AUDIT 의 모든 필드를 같은 타입으로 갖고 있는지 확인
    METHODS check_row_type
      IMPORTING is_row TYPE any
      RAISING   zcx_cih_audit.

    "! 이번 호출에서 쓸 감사 값 한 벌 (created_* = changed_* = 현재 사용자/시각)
    METHODS build_audit
      RETURNING VALUE(rs_audit) TYPE zs_cih_audit
      RAISING   zcx_cih_audit.

    METHODS apply
      IMPORTING iv_insert TYPE abap_bool
                is_new    TYPE zs_cih_audit
      CHANGING  cs_row    TYPE any.
ENDCLASS.


CLASS zcl_cih_audit IMPLEMENTATION.

  METHOD create.
    ro_audit = NEW #( COND #( WHEN io_context IS BOUND THEN io_context
                              ELSE NEW zcl_cih_audit_context( ) ) ).
  ENDMETHOD.

  METHOD constructor.
    mo_context = io_context.
  ENDMETHOD.

  METHOD set_for_insert.
    stamp_table( EXPORTING iv_insert = abap_true CHANGING ct_data = ct_data ).
  ENDMETHOD.

  METHOD set_for_update.
    stamp_table( EXPORTING iv_insert = abap_false CHANGING ct_data = ct_data ).
  ENDMETHOD.

  METHOD set_for_insert_single.
    stamp_single( EXPORTING iv_insert = abap_true CHANGING cs_data = cs_data ).
  ENDMETHOD.

  METHOD set_for_update_single.
    stamp_single( EXPORTING iv_insert = abap_false CHANGING cs_data = cs_data ).
  ENDMETHOD.

  METHOD stamp_table.
    DATA lr_line TYPE REF TO data.

    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    " 행 타입 검사는 한 번만 (라인 타입의 빈 작업영역으로)
    CREATE DATA lr_line LIKE LINE OF ct_data.
    ASSIGN lr_line->* TO FIELD-SYMBOL(<ls_line>).
    check_row_type( <ls_line> ).

    " 값도 한 번만 → 같은 호출의 모든 행이 같은 사용자/시각
    DATA(ls_new) = build_audit( ).

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_row>).
      apply( EXPORTING iv_insert = iv_insert is_new = ls_new
             CHANGING  cs_row    = <ls_row> ).
    ENDLOOP.
  ENDMETHOD.

  METHOD stamp_single.
    check_row_type( cs_data ).
    apply( EXPORTING iv_insert = iv_insert is_new = build_audit( )
           CHANGING  cs_row    = cs_data ).
  ENDMETHOD.

  METHOD check_row_type.
    DATA ls_audit TYPE zs_cih_audit.

    DATA(lo_row) = cl_abap_typedescr=>describe_by_data( is_row ).
    IF lo_row->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION NEW zcx_cih_audit( iv_text = |{ lo_row->absolute_name } 는 구조체(행) 타입이 아닙니다.| ).
    ENDIF.

    " 감사 구조체의 (인클루드까지 펼친) 컴포넌트 목록 = 필드 이름·타입의 원천
    DATA(lo_audit) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( ls_audit ) ).

    LOOP AT lo_audit->get_included_view( ) INTO DATA(ls_comp).
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_field>).
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_cih_audit(
          iv_text = |{ lo_row->absolute_name } 에 감사필드 { ls_comp-name } 가 없습니다 (ZS_CIH_AUDIT 인클루드 확인).| ).
      ENDIF.

      DATA(lo_field) = cl_abap_typedescr=>describe_by_data( <lv_field> ).
      IF lo_field->absolute_name <> ls_comp-type->absolute_name.
        RAISE EXCEPTION NEW zcx_cih_audit(
          iv_text = |{ lo_row->absolute_name }-{ ls_comp-name }: 타입 { lo_field->absolute_name } 가 | &&
                    |ZS_CIH_AUDIT 의 { ls_comp-type->absolute_name } 와 다릅니다.| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_audit.
    DATA(lv_user) = mo_context->get_user( ).
    DATA(lv_now)  = mo_context->get_now( ).

    rs_audit-created_by = lv_user.
    rs_audit-changed_by = lv_user.
    TRY.
        " ZS_CIH_AUDIT 의 시각 필드는 TIMESTAMPL (구조체 타입이 바뀌면 여기서 문법 오류로 드러남)
        rs_audit-created_at = cl_abap_tstmp=>utclong2tstmp( lv_now ).
        rs_audit-changed_at = rs_audit-created_at.
      CATCH cx_sy_conversion_no_date_time INTO DATA(lx_conv).
        RAISE EXCEPTION NEW zcx_cih_audit( iv_text = `현재 시각을 타임스탬프로 변환하지 못했습니다.`
                                           previous = lx_conv ).
    ENDTRY.
  ENDMETHOD.

  METHOD apply.
    DATA ls_audit TYPE zs_cih_audit.

    IF iv_insert = abap_true.
      ls_audit = is_new.
    ELSE.
      " 행의 기존 감사 값(created_*)을 가져오고 changed_* 만 교체
      MOVE-CORRESPONDING cs_row TO ls_audit.
      ls_audit-changed_by = is_new-changed_by.
      ls_audit-changed_at = is_new-changed_at.
    ENDIF.

    " 같은 이름의 필드(= ZS_CIH_AUDIT 필드)만 행에 복사, 나머지 필드는 그대로
    MOVE-CORRESPONDING ls_audit TO cs_row.
  ENDMETHOD.

ENDCLASS.
