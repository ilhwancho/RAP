"! ZCL_CIH_CREDIT_DATA_DB 테스트 - fixture 메서드 4개(class_setup / setup / teardown / class_teardown)를 모두 사용하는 데모
"! 진짜 테이블 대신 CL_OSQL_TEST_ENVIRONMENT 가 만든 가짜 테이블에 SELECT 하게 한다.
CLASS ltc_credit_data_db DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA go_env   TYPE REF TO if_osql_test_environment.  " 클래스 전체가 같이 쓰는 가짜 DB 환경
    CLASS-DATA gt_trace TYPE string_table.                     " fixture 호출 기록 (데모용)

    DATA mo_cut TYPE REF TO zif_cih_credit_data.                " 테스트 대상 (Code Under Test)

    " ── fixture: 이름이 정해져 있고 PRIVATE, FOR TESTING 을 붙이지 않는다 ──
    CLASS-METHODS class_setup.       " 모든 테스트 전에 1번
    CLASS-METHODS class_teardown.    " 모든 테스트 후에 1번
    METHODS setup.                   " 테스트 메서드마다 실행 전
    METHODS teardown.                " 테스트 메서드마다 실행 후

    " ── 테스트 메서드 ──
    METHODS limit_of_registered_customer FOR TESTING RAISING cx_static_check.
    METHODS unknown_customer_raises      FOR TESTING.
    METHODS open_sums_only_accepted      FOR TESTING.
    METHODS open_is_zero_without_orders  FOR TESTING.
    METHODS fixture_order                FOR TESTING.
ENDCLASS.

CLASS ltc_credit_data_db IMPLEMENTATION.

  METHOD class_setup.
    " 비용이 큰 준비는 한 번만: 두 테이블의 가짜(double)를 만들고, 이후 SELECT 를 가짜로 돌린다
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZAT_CIH_CRLIM' ) ( 'ZAT_CIH_SOH' ) ) ).
    APPEND `CLASS_SETUP` TO gt_trace.
  ENDMETHOD.

  METHOD class_teardown.
    " 가짜 환경 해제 → 이후 SELECT 는 다시 진짜 테이블로
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    " 테스트마다 같은 출발점: 테스트 데이터 넣고, 테스트 대상 새로 만들기
    DATA lt_limit TYPE STANDARD TABLE OF zat_cih_crlim WITH EMPTY KEY.
    DATA lt_order TYPE STANDARD TABLE OF zat_cih_soh   WITH EMPTY KEY.
    lt_limit = VALUE #( ( customer_id = 'C1' credit_limit = '100.00' currency_code = 'KRW' ) ).
    lt_order = VALUE #( ( sales_order_uuid = '01' customer_id = 'C1' overall_status = 'A' total_amount = '10.00' )
                        ( sales_order_uuid = '02' customer_id = 'C1' overall_status = 'A' total_amount = '20.00' )
                        ( sales_order_uuid = '03' customer_id = 'C1' overall_status = 'O' total_amount = '40.00' )   " 미승인 → 제외
                        ( sales_order_uuid = '04' customer_id = 'C1' overall_status = 'X' total_amount = '80.00' )   " 거절 → 제외
                        ( sales_order_uuid = '05' customer_id = 'C2' overall_status = 'A' total_amount = '99.00' ) ). " 다른 고객 → 제외
    go_env->insert_test_data( i_data = lt_limit ).
    go_env->insert_test_data( i_data = lt_order ).

    mo_cut = NEW zcl_cih_credit_data_db( ).
    APPEND `SETUP` TO gt_trace.
  ENDMETHOD.

  METHOD teardown.
    " 테스트마다 뒷정리: 가짜 테이블을 비워서 다음 테스트에 데이터가 남지 않게
    go_env->clear_doubles( ).
    CLEAR mo_cut.
    APPEND `TEARDOWN` TO gt_trace.
  ENDMETHOD.


  METHOD limit_of_registered_customer.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_limit( 'C1' ) exp = '100.00' ).
  ENDMETHOD.

  METHOD unknown_customer_raises.
    TRY.
        mo_cut->get_limit( 'C9' ).
        cl_abap_unit_assert=>fail( '미등록 고객인데 예외가 나지 않음' ).
      CATCH zcx_cih_customer_unknown INTO DATA(lx).
        cl_abap_unit_assert=>assert_equals( act = lx->customer exp = 'C9' ).
    ENDTRY.
  ENDMETHOD.

  METHOD open_sums_only_accepted.
    " C1 의 승인(A) 오더만: 10 + 20 = 30
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_open_amount( 'C1' ) exp = '30.00' ).
  ENDMETHOD.

  METHOD open_is_zero_without_orders.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->get_open_amount( 'C3' ) exp = 0 ).
  ENDMETHOD.

  METHOD fixture_order.
    " 테스트 순서는 보장되지 않지만, 어느 테스트에서 봐도 항상 성립하는 것:
    "  - 맨 처음은 CLASS_SETUP (1번만)
    "  - 맨 끝은 방금 실행된 SETUP (지금 이 테스트 직전)
    "  - SETUP 은 TEARDOWN 보다 정확히 1번 더 많다 (지금 테스트의 TEARDOWN 은 아직 안 불림)
    cl_abap_unit_assert=>assert_equals( act = gt_trace[ 1 ] exp = `CLASS_SETUP` ).
    cl_abap_unit_assert=>assert_equals( act = gt_trace[ lines( gt_trace ) ] exp = `SETUP` ).
    DATA(lv_setup)    = REDUCE i( INIT n = 0 FOR t IN gt_trace WHERE ( table_line = `SETUP` )    NEXT n = n + 1 ).
    DATA(lv_teardown) = REDUCE i( INIT n = 0 FOR t IN gt_trace WHERE ( table_line = `TEARDOWN` ) NEXT n = n + 1 ).
    DATA(lv_cls)      = REDUCE i( INIT n = 0 FOR t IN gt_trace WHERE ( table_line = `CLASS_SETUP` ) NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_setup - lv_teardown exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_cls exp = 1 ).
  ENDMETHOD.

ENDCLASS.
