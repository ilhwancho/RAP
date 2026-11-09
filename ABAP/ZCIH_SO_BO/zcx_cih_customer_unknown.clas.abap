"! 신용한도가 등록되지 않은 고객
CLASS zcx_cih_customer_unknown DEFINITION PUBLIC INHERITING FROM zcx_cih_credit FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA customer TYPE zif_cih_credit_check=>ty_customer READ-ONLY.
    METHODS constructor
      IMPORTING customer TYPE zif_cih_credit_check=>ty_customer
                previous LIKE previous OPTIONAL.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.

CLASS zcx_cih_customer_unknown IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->customer = customer.
  ENDMETHOD.

  METHOD if_message~get_text.
    result = |고객 { customer } 의 신용한도가 등록되어 있지 않습니다.|.
  ENDMETHOD.
ENDCLASS.
