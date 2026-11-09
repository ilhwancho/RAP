"! 가짜 데이터 부품: DB 대신 테스트가 정한 값을 돌려준다
CLASS ltd_credit_data DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cih_credit_data.
    DATA mv_limit TYPE zif_cih_credit_check=>ty_amount.
    DATA mv_open  TYPE zif_cih_credit_check=>ty_amount.
    DATA mv_known TYPE abap_bool VALUE abap_true.
ENDCLASS.

CLASS ltd_credit_data IMPLEMENTATION.
  METHOD zif_cih_credit_data~get_limit.
    IF mv_known = abap_false.
      RAISE EXCEPTION NEW zcx_cih_customer_unknown( customer = iv_customer ).
    ENDIF.
    rv_limit = mv_limit.
  ENDMETHOD.

  METHOD zif_cih_credit_data~get_open_amount.
    rv_open = mv_open.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_credit_check DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_data  TYPE REF TO ltd_credit_data.
    DATA mo_check TYPE REF TO zif_cih_credit_check.

    METHODS setup.
    METHODS within_limit_passes     FOR TESTING RAISING cx_static_check.
    METHODS exact_limit_passes      FOR TESTING RAISING cx_static_check.
    METHODS over_limit_raises       FOR TESTING.
    METHODS unknown_customer_raises FOR TESTING.
ENDCLASS.

CLASS ltc_credit_check IMPLEMENTATION.
  METHOD setup.
    mo_data = NEW ltd_credit_data( ).
    mo_data->mv_limit = 1000.
    mo_data->mv_open  = 700.
    mo_check = zcl_cih_credit_check=>create_with( mo_data ).    " ← 가짜 부품 주입
  ENDMETHOD.

  METHOD within_limit_passes.
    mo_check->check( iv_customer = 'C1' iv_amount = 200 iv_currency = 'EUR' ).   " 700 + 200 <= 1000
  ENDMETHOD.

  METHOD exact_limit_passes.
    mo_check->check( iv_customer = 'C1' iv_amount = 300 iv_currency = 'EUR' ).   " 700 + 300 = 1000
  ENDMETHOD.

  METHOD over_limit_raises.
    TRY.
        mo_check->check( iv_customer = 'C1' iv_amount = 301 iv_currency = 'EUR' ).
        cl_abap_unit_assert=>fail( '한도 초과인데 예외가 나지 않음' ).
      CATCH zcx_cih_credit_exceeded INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->open_amount  exp = 700 ).
        cl_abap_unit_assert=>assert_equals( act = lx->order_amount exp = 301 ).
      CATCH zcx_cih_credit.
        cl_abap_unit_assert=>fail( '다른 종류의 예외' ).
    ENDTRY.
  ENDMETHOD.

  METHOD unknown_customer_raises.
    mo_data->mv_known = abap_false.
    TRY.
        mo_check->check( iv_customer = 'C9' iv_amount = 1 iv_currency = 'EUR' ).
        cl_abap_unit_assert=>fail( '미등록 고객인데 예외가 나지 않음' ).
      CATCH zcx_cih_customer_unknown INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->customer exp = 'C9' ).
      CATCH zcx_cih_credit.
        cl_abap_unit_assert=>fail( '다른 종류의 예외' ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
