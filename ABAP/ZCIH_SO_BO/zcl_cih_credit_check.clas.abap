"! 신용한도 체크 본체 - NEW 금지, create( ) 로만 생성
CLASS zcl_cih_credit_check DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    INTERFACES zif_cih_credit_check.

    "! 운영용: 진짜 DB 조회 부품을 넣어서 만든다
    CLASS-METHODS create
      RETURNING VALUE(ro_check) TYPE REF TO zif_cih_credit_check.

    "! 테스트용: 데이터 조회 부품을 밖에서 넣는다
    CLASS-METHODS create_with
      IMPORTING io_data         TYPE REF TO zif_cih_credit_data
      RETURNING VALUE(ro_check) TYPE REF TO zif_cih_credit_check.

    METHODS constructor
      IMPORTING io_data TYPE REF TO zif_cih_credit_data.

  PRIVATE SECTION.
    DATA mo_data TYPE REF TO zif_cih_credit_data.
ENDCLASS.

CLASS zcl_cih_credit_check IMPLEMENTATION.
  METHOD create.
    ro_check = NEW zcl_cih_credit_check( io_data = NEW zcl_cih_credit_data_db( ) ).
  ENDMETHOD.

  METHOD create_with.
    ro_check = NEW zcl_cih_credit_check( io_data = io_data ).
  ENDMETHOD.

  METHOD constructor.
    mo_data = io_data.
  ENDMETHOD.

  METHOD zif_cih_credit_check~check.
    DATA(lv_limit) = mo_data->get_limit( iv_customer ).
    DATA(lv_open)  = mo_data->get_open_amount( iv_customer ).

    IF lv_open + iv_amount > lv_limit.
      RAISE EXCEPTION NEW zcx_cih_credit_exceeded( customer     = iv_customer
                                                   credit_limit = lv_limit
                                                   open_amount  = lv_open
                                                   order_amount = iv_amount
                                                   currency     = iv_currency ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
