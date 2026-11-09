"! acceptOrder 액션 핸들러 테스트 (방식 A: 핸들러 메서드 직접 호출, EML 없이)
"! @testing BDEF:ZR_CIH_SALESORDER
CLASS ltc_accept_order DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES tt_keys     TYPE TABLE FOR ACTION IMPORT zr_cih_salesorder\\SalesOrder~acceptOrder.
    TYPES tt_result   TYPE TABLE FOR ACTION RESULT zr_cih_salesorder\\SalesOrder~acceptOrder.

    CLASS-DATA mo_cut TYPE REF TO lhc_salesorder.              " 테스트 대상: 핸들러 (FRIENDS 로 private 메서드 접근)
    CLASS-DATA go_cds TYPE REF TO if_cds_test_environment.     " ZR_CIH_SalesOrder 를 가짜 데이터로
    CLASS-DATA go_sql TYPE REF TO if_osql_test_environment.    " 신용한도 클래스가 직접 SELECT 하는 테이블을 가짜로

    DATA ms_result   TYPE tt_result.
    DATA ms_mapped   TYPE RESPONSE FOR MAPPED EARLY zr_cih_salesorder.
    DATA ms_failed   TYPE RESPONSE FOR FAILED EARLY zr_cih_salesorder.
    DATA ms_reported TYPE RESPONSE FOR REPORTED EARLY zr_cih_salesorder.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS accept_within_limit     FOR TESTING.
    METHODS reject_over_limit       FOR TESTING.
    METHODS reject_with_open_amount FOR TESTING.
    METHODS reject_unknown_customer FOR TESTING.

    " ── 헬퍼 ──
    METHODS given_order
      IMPORTING iv_uuid TYPE sysuuid_x16 iv_customer TYPE zat_cih_soh-customer_id
                iv_amount TYPE zat_cih_soh-total_amount iv_status TYPE zat_cih_soh-overall_status DEFAULT 'O'.
    METHODS given_limit
      IMPORTING iv_customer TYPE zat_cih_crlim-customer_id iv_limit TYPE zat_cih_crlim-credit_limit.
    METHODS when_accept
      IMPORTING iv_uuid TYPE sysuuid_x16.
    METHODS first_message RETURNING VALUE(rv) TYPE string.
ENDCLASS.

CLASS ltc_accept_order IMPLEMENTATION.

  METHOD class_setup.
    CREATE OBJECT mo_cut FOR TESTING.     " RAP 핸들러는 NEW 불가, 이 방법으로만 생성
    go_cds = cl_cds_test_environment=>create( i_for_entity = 'ZR_CIH_SALESORDER' ).
    go_sql = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZAT_CIH_SOH' ) ( 'ZAT_CIH_CRLIM' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_cds->destroy( ).
    go_sql->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_cds->clear_doubles( ).
    go_sql->clear_doubles( ).
    CLEAR: ms_result, ms_mapped, ms_failed, ms_reported.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.                    " 핸들러가 바꾼 트랜잭션 버퍼 버리기
  ENDMETHOD.


  METHOD accept_within_limit.
    given_order( iv_uuid = '000000000000000000000000000000A1' iv_customer = 'TC1' iv_amount = '60.00' ).
    given_limit( iv_customer = 'TC1' iv_limit = '100.00' ).

    when_accept( '000000000000000000000000000000A1' ).

    cl_abap_unit_assert=>assert_initial( act = ms_failed-salesorder msg = 'failed 가 비어 있어야 함' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ms_result ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ms_result[ 1 ]-%param-OverallStatus exp = 'A' ).
  ENDMETHOD.

  METHOD reject_over_limit.
    given_order( iv_uuid = '000000000000000000000000000000A2' iv_customer = 'TC2' iv_amount = '60.00' ).
    given_limit( iv_customer = 'TC2' iv_limit = '50.00' ).

    when_accept( '000000000000000000000000000000A2' ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_failed-salesorder msg = '거부되어야 함' ).
    cl_abap_unit_assert=>assert_initial( act = ms_result ).
    cl_abap_unit_assert=>assert_char_cp( act = first_message( ) exp = '한도초과*' ).
  ENDMETHOD.

  METHOD reject_with_open_amount.
    given_order( iv_uuid = '000000000000000000000000000000A3' iv_customer = 'TC3' iv_amount = '60.00' ).
    given_order( iv_uuid = '000000000000000000000000000000A4' iv_customer = 'TC3' iv_amount = '60.00' iv_status = 'A' ).
    given_limit( iv_customer = 'TC3' iv_limit = '100.00' ).        " 기승인 60 + 이번 60 > 100

    when_accept( '000000000000000000000000000000A3' ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_failed-salesorder msg = '기승인 금액 포함 시 거부되어야 함' ).
  ENDMETHOD.

  METHOD reject_unknown_customer.
    given_order( iv_uuid = '000000000000000000000000000000A5' iv_customer = 'TC9' iv_amount = '60.00' ).

    when_accept( '000000000000000000000000000000A5' ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_failed-salesorder ).
    cl_abap_unit_assert=>assert_char_cp( act = first_message( ) exp = '*TC9*' ).
  ENDMETHOD.


  METHOD given_order.
    DATA lt_order TYPE STANDARD TABLE OF zat_cih_soh WITH EMPTY KEY.
    lt_order = VALUE #( ( sales_order_uuid = iv_uuid customer_id = iv_customer overall_status = iv_status
                          total_amount = iv_amount currency_code = 'KRW' ) ).
    go_cds->insert_test_data( lt_order ).   " 핸들러의 READ ENTITIES 용
    go_sql->insert_test_data( lt_order ).   " 신용한도 클래스의 SELECT 용
  ENDMETHOD.

  METHOD given_limit.
    DATA lt_limit TYPE STANDARD TABLE OF zat_cih_crlim WITH EMPTY KEY.
    lt_limit = VALUE #( ( customer_id = iv_customer credit_limit = iv_limit currency_code = 'KRW' ) ).
    go_sql->insert_test_data( lt_limit ).
  ENDMETHOD.

  METHOD when_accept.
    mo_cut->acceptorder( EXPORTING keys     = VALUE tt_keys( ( %tky-%is_draft = if_abap_behv=>mk-off
                                                               %tky-SalesOrderUUID = iv_uuid ) )
                         CHANGING  result   = ms_result
                                   mapped   = ms_mapped
                                   failed   = ms_failed
                                   reported = ms_reported ).
  ENDMETHOD.

  METHOD first_message.
    LOOP AT ms_reported-salesorder INTO DATA(r) WHERE %msg IS BOUND.
      rv = r-%msg->if_message~get_text( ).
      RETURN.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
