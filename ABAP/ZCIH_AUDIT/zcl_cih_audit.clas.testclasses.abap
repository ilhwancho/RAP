*"* use this source file for your ABAP unit test classes

"! 고정 사용자/시각을 돌려주는 test double
CLASS ltd_context DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cih_audit_context.
    DATA mv_user TYPE string.
    DATA mv_now  TYPE utclong.
ENDCLASS.

CLASS ltd_context IMPLEMENTATION.
  METHOD zif_cih_audit_context~get_user.
    rv_user = mv_user.
  ENDMETHOD.
  METHOD zif_cih_audit_context~get_now.
    rv_now = mv_now.
  ENDMETHOD.
ENDCLASS.


"! @testing ZCL_CIH_AUDIT
CLASS ltc_audit DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    " 그룹명 없이 인클루드 (실제 테이블과 같은 형태)
    TYPES BEGIN OF ty_row.
    TYPES   id   TYPE i.
    TYPES   text TYPE string.
    INCLUDE TYPE zs_cih_audit.
    TYPES END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_row_no_audit,
        id TYPE i,
      END OF ty_row_no_audit,
      " 이름은 같지만 타입이 다른 경우 (created_at 이 UTCLONG)
      BEGIN OF ty_row_bad_type,
        id         TYPE i,
        created_by TYPE abp_creation_user,
        created_at TYPE utclong,
        changed_by TYPE abp_lastchange_user,
        changed_at TYPE abp_lastchange_tstmpl,
      END OF ty_row_bad_type.

    CONSTANTS c_now_tstmpl TYPE timestampl VALUE '20261111102030.1234567'.

    DATA mo_context TYPE REF TO ltd_context.
    DATA mo_cut     TYPE REF TO zcl_cih_audit.

    METHODS setup.
    METHODS insert_sets_all_fields     FOR TESTING RAISING cx_static_check.
    METHODS insert_keeps_other_fields  FOR TESTING RAISING cx_static_check.
    METHODS update_keeps_created       FOR TESTING RAISING cx_static_check.
    METHODS same_values_for_all_rows   FOR TESTING RAISING cx_static_check.
    METHODS single_row                 FOR TESTING RAISING cx_static_check.
    METHODS empty_table_is_ok          FOR TESTING RAISING cx_static_check.
    METHODS missing_fields_raise       FOR TESTING.
    METHODS different_type_raises      FOR TESTING.
ENDCLASS.


CLASS ltc_audit IMPLEMENTATION.

  METHOD setup.
    mo_context = NEW #( ).
    mo_context->mv_user = `TESTUSER`.
    mo_context->mv_now  = CONV utclong( '2026-11-11T10:20:30.1234567' ).
    mo_cut = zcl_cih_audit=>create( mo_context ).
  ENDMETHOD.

  METHOD insert_sets_all_fields.
    DATA(lt_data) = VALUE tt_row( ( id = 1 ) ).

    mo_cut->set_for_insert( CHANGING ct_data = lt_data ).

    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-created_by exp = 'TESTUSER' ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-changed_by exp = 'TESTUSER' ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-created_at exp = c_now_tstmpl ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-changed_at exp = c_now_tstmpl ).
  ENDMETHOD.

  METHOD insert_keeps_other_fields.
    DATA(lt_data) = VALUE tt_row( ( id = 7 text = `keep me` ) ).

    mo_cut->set_for_insert( CHANGING ct_data = lt_data ).

    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-id   exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-text exp = `keep me` ).
  ENDMETHOD.

  METHOD update_keeps_created.
    DATA(lt_data) = VALUE tt_row( ( id         = 1
                                    created_by = 'OLDUSER'
                                    created_at = '20250101000000.0000000'
                                    changed_by = 'OLDUSER'
                                    changed_at = '20250101000000.0000000' ) ).

    mo_cut->set_for_update( CHANGING ct_data = lt_data ).

    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-created_by exp = 'OLDUSER' ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-created_at
                                        exp = CONV timestampl( '20250101000000.0000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-changed_by exp = 'TESTUSER' ).
    cl_abap_unit_assert=>assert_equals( act = lt_data[ 1 ]-changed_at exp = c_now_tstmpl ).
  ENDMETHOD.

  METHOD same_values_for_all_rows.
    DATA(lt_data) = VALUE tt_row( ( id = 1 ) ( id = 2 ) ( id = 3 ) ).

    mo_cut->set_for_insert( CHANGING ct_data = lt_data ).

    LOOP AT lt_data INTO DATA(ls_row).
      cl_abap_unit_assert=>assert_equals( act = ls_row-created_at exp = c_now_tstmpl ).
      cl_abap_unit_assert=>assert_equals( act = ls_row-changed_at exp = c_now_tstmpl ).
    ENDLOOP.
  ENDMETHOD.

  METHOD single_row.
    DATA(ls_row) = VALUE ty_row( id = 1 ).

    mo_cut->set_for_insert_single( CHANGING cs_data = ls_row ).

    cl_abap_unit_assert=>assert_equals( act = ls_row-created_by exp = 'TESTUSER' ).
  ENDMETHOD.

  METHOD empty_table_is_ok.
    DATA lt_data TYPE tt_row.

    mo_cut->set_for_insert( CHANGING ct_data = lt_data ).

    cl_abap_unit_assert=>assert_initial( lt_data ).
  ENDMETHOD.

  METHOD missing_fields_raise.
    DATA lt_data TYPE STANDARD TABLE OF ty_row_no_audit WITH EMPTY KEY.
    lt_data = VALUE #( ( id = 1 ) ).

    TRY.
        mo_cut->set_for_insert( CHANGING ct_data = lt_data ).
        cl_abap_unit_assert=>fail( 'ZCX_CIH_AUDIT expected' ).
      CATCH zcx_cih_audit ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD different_type_raises.
    DATA lt_data TYPE STANDARD TABLE OF ty_row_bad_type WITH EMPTY KEY.
    lt_data = VALUE #( ( id = 1 ) ).

    TRY.
        mo_cut->set_for_update( CHANGING ct_data = lt_data ).
        cl_abap_unit_assert=>fail( 'ZCX_CIH_AUDIT expected' ).
      CATCH zcx_cih_audit ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
