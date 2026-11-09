"! 신용한도 데이터 - 진짜 DB 조회 구현
CLASS zcl_cih_credit_data_db DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_cih_credit_data.
ENDCLASS.

CLASS zcl_cih_credit_data_db IMPLEMENTATION.
  METHOD zif_cih_credit_data~get_limit.
    SELECT SINGLE credit_limit FROM zat_cih_crlim
      WHERE customer_id = @iv_customer
      INTO @rv_limit.
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_cih_customer_unknown( customer = iv_customer ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_cih_credit_data~get_open_amount.
    SELECT SINGLE SUM( total_amount ) FROM zat_cih_soh
      WHERE customer_id    = @iv_customer
        AND overall_status = 'A'
      INTO @rv_open.
  ENDMETHOD.
ENDCLASS.
