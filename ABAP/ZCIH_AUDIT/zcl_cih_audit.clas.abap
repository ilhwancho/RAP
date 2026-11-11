"! <p class="shorttext synchronized">감사필드(ZS_CIH_AUDIT) 세팅 헬퍼</p>
"! 테이블에 ZS_CIH_AUDIT 를 <strong>그룹명 없이</strong> 인클루드해도 된다:
"!   include zs_cih_audit;
"! 인클루드 필드는 행 구조에 평평하게 펼쳐지므로, 필드 이름(CREATED_BY ...)으로 찾는다.
"! 이 클래스는 값만 채운다. INSERT/UPDATE 는 호출하는 쪽에서 한다.
"! RAP managed BO 테이블은 대상 아님 (CDS @Semantics.user/systemDateTime 로 프레임워크가 채움,
"! docs/rap-internals/08-admin-fields.md).
"!
"! 프레임워크(CL_CSP_ACT_SET_ADMIN_DATA)에서 가져온 것:
"! - 시각은 호출당 1회 utclong 으로 구하고, 필드 타입(UTCLONG/TIMESTAMPL/TIMESTAMP)에 맞춰 변환
"! - 사용자/시각 제공자를 인터페이스로 분리 (테스트에서 교체)
CLASS zcl_cih_audit DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_field,
        created_by TYPE string VALUE 'CREATED_BY',
        created_at TYPE string VALUE 'CREATED_AT',
        changed_by TYPE string VALUE 'CHANGED_BY',
        changed_at TYPE string VALUE 'CHANGED_AT',
      END OF c_field.

    "! @parameter io_context | 생략하면 ZCL_CIH_AUDIT_CONTEXT (현재 사용자, utclong_current)
    CLASS-METHODS create
      IMPORTING io_context      TYPE REF TO zif_cih_audit_context OPTIONAL
      RETURNING VALUE(ro_audit) TYPE REF TO zcl_cih_audit.

    "! INSERT 전: CREATED_* + CHANGED_* 세팅. 행 구조에 4개 필드가 모두 있어야 한다.
    METHODS set_for_insert
      CHANGING ct_data TYPE STANDARD TABLE
      RAISING  zcx_cih_audit.

    "! UPDATE 전: CHANGED_* 만 세팅 (CREATED_* 는 건드리지 않음).
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
    "! 필드 종류: 사용자(문자) / UTCLONG / TIMESTAMPL / TIMESTAMP
    TYPES ty_kind TYPE c LENGTH 1.
    CONSTANTS:
      BEGIN OF c_kind,
        user    TYPE ty_kind VALUE 'C',
        utclong TYPE ty_kind VALUE 'U',
        tstmpl  TYPE ty_kind VALUE 'L',
        tstmp   TYPE ty_kind VALUE 'S',
      END OF c_kind.

    TYPES:
      BEGIN OF ty_target,
        name TYPE string,
        kind TYPE ty_kind,
      END OF ty_target,
      tt_target TYPE STANDARD TABLE OF ty_target WITH EMPTY KEY.

    "! 한 호출에서 쓰는 값 한 벌 (타입별로 미리 변환)
    TYPES:
      BEGIN OF ty_values,
        user    TYPE string,
        utclong TYPE utclong,
        tstmpl  TYPE timestampl,
        tstmp   TYPE timestamp,
      END OF ty_values.

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

    "! 행 구조를 보고 채울 필드와 각 필드의 종류를 결정
    METHODS analyze
      IMPORTING is_row           TYPE any
                iv_insert        TYPE abap_bool
      RETURNING VALUE(rt_target) TYPE tt_target
      RAISING   zcx_cih_audit.

    METHODS get_kind
      IMPORTING iv_name        TYPE string
                iv_value       TYPE any
                iv_is_user     TYPE abap_bool
                iv_type_name   TYPE string
      RETURNING VALUE(rv_kind) TYPE ty_kind
      RAISING   zcx_cih_audit.

    METHODS get_values
      RETURNING VALUE(rs_values) TYPE ty_values
      RAISING   zcx_cih_audit.

    METHODS apply
      IMPORTING it_target TYPE tt_target
                is_values TYPE ty_values
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

    " 행 타입 분석은 한 번만 (라인 타입의 빈 작업영역으로)
    CREATE DATA lr_line LIKE LINE OF ct_data.
    ASSIGN lr_line->* TO FIELD-SYMBOL(<ls_line>).
    DATA(lt_target) = analyze( is_row = <ls_line> iv_insert = iv_insert ).

    " 값도 한 번만 → 같은 호출의 모든 행이 같은 사용자/시각
    DATA(ls_values) = get_values( ).

    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_row>).
      apply( EXPORTING it_target = lt_target is_values = ls_values
             CHANGING  cs_row    = <ls_row> ).
    ENDLOOP.
  ENDMETHOD.

  METHOD stamp_single.
    DATA(lt_target) = analyze( is_row = cs_data iv_insert = iv_insert ).
    apply( EXPORTING it_target = lt_target is_values = get_values( )
           CHANGING  cs_row    = cs_data ).
  ENDMETHOD.

  METHOD analyze.
    DATA lt_name TYPE string_table.

    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( is_row ).
    DATA(lv_type_name) = lo_type->absolute_name.
    IF lo_type->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION NEW zcx_cih_audit( iv_text = |{ lv_type_name } 는 구조체(행) 타입이 아닙니다.| ).
    ENDIF.

    IF iv_insert = abap_true.
      lt_name = VALUE #( ( c_field-created_by ) ( c_field-created_at )
                         ( c_field-changed_by ) ( c_field-changed_at ) ).
    ELSE.
      lt_name = VALUE #( ( c_field-changed_by ) ( c_field-changed_at ) ).
    ENDIF.

    LOOP AT lt_name INTO DATA(lv_name).
      " 그룹명 없는 인클루드의 필드도 이름으로 바로 접근된다
      ASSIGN COMPONENT lv_name OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_field>).
      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW zcx_cih_audit(
          iv_text = |{ lv_type_name } 에 감사필드 { lv_name } 가 없습니다 (ZS_CIH_AUDIT 인클루드 확인).| ).
      ENDIF.

      APPEND VALUE #( name = lv_name
                      kind = get_kind( iv_name      = lv_name
                                       iv_value     = <lv_field>
                                       iv_is_user   = xsdbool( lv_name = c_field-created_by OR
                                                               lv_name = c_field-changed_by )
                                       iv_type_name = lv_type_name ) ) TO rt_target.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_kind.
    DATA(lo_elem) = cl_abap_typedescr=>describe_by_data( iv_value ).

    IF iv_is_user = abap_true.
      IF lo_elem->type_kind = cl_abap_typedescr=>typekind_char OR
         lo_elem->type_kind = cl_abap_typedescr=>typekind_string.
        rv_kind = c_kind-user.
        RETURN.
      ENDIF.
    ELSE.
      CASE lo_elem->type_kind.
        WHEN cl_abap_typedescr=>typekind_utclong.
          rv_kind = c_kind-utclong.
          RETURN.
        WHEN cl_abap_typedescr=>typekind_packed.
          " TIMESTAMPL = p(11) dec 7, TIMESTAMP = p(8) dec 0
          CASE lo_elem->decimals.
            WHEN 7.
              rv_kind = c_kind-tstmpl.
              RETURN.
            WHEN 0.
              rv_kind = c_kind-tstmp.
              RETURN.
          ENDCASE.
      ENDCASE.
    ENDIF.

    RAISE EXCEPTION NEW zcx_cih_audit(
      iv_text = |{ iv_type_name }-{ iv_name }: 지원하지 않는 타입 ({ lo_elem->absolute_name }).| ).
  ENDMETHOD.

  METHOD get_values.
    rs_values-user    = mo_context->get_user( ).
    rs_values-utclong = mo_context->get_now( ).
    TRY.
        rs_values-tstmpl = cl_abap_tstmp=>utclong2tstmp( rs_values-utclong ).
        rs_values-tstmp  = cl_abap_tstmp=>utclong2tstmp_short( rs_values-utclong ).
      CATCH cx_sy_conversion_no_date_time INTO DATA(lx_conv).
        RAISE EXCEPTION NEW zcx_cih_audit( iv_text = `현재 시각을 타임스탬프로 변환하지 못했습니다.`
                                           previous = lx_conv ).
    ENDTRY.
  ENDMETHOD.

  METHOD apply.
    LOOP AT it_target ASSIGNING FIELD-SYMBOL(<ls_target>).
      ASSIGN COMPONENT <ls_target>-name OF STRUCTURE cs_row TO FIELD-SYMBOL(<lv_field>).
      CASE <ls_target>-kind.
        WHEN c_kind-user.    <lv_field> = is_values-user.
        WHEN c_kind-utclong. <lv_field> = is_values-utclong.
        WHEN c_kind-tstmpl.  <lv_field> = is_values-tstmpl.
        WHEN c_kind-tstmp.   <lv_field> = is_values-tstmp.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
