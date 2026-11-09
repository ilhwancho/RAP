"! 신용한도 초과
CLASS zcx_cih_credit_exceeded DEFINITION PUBLIC INHERITING FROM zcx_cih_credit FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA customer     TYPE zif_cih_credit_check=>ty_customer READ-ONLY.
    DATA credit_limit TYPE zif_cih_credit_check=>ty_amount   READ-ONLY.
    DATA open_amount  TYPE zif_cih_credit_check=>ty_amount   READ-ONLY.
    DATA order_amount TYPE zif_cih_credit_check=>ty_amount   READ-ONLY.
    DATA currency     TYPE zif_cih_credit_check=>ty_currency READ-ONLY.

    METHODS constructor
      IMPORTING customer     TYPE zif_cih_credit_check=>ty_customer
                credit_limit TYPE zif_cih_credit_check=>ty_amount
                open_amount  TYPE zif_cih_credit_check=>ty_amount
                order_amount TYPE zif_cih_credit_check=>ty_amount
                currency     TYPE zif_cih_credit_check=>ty_currency
                previous     LIKE previous OPTIONAL.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.

CLASS zcx_cih_credit_exceeded IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->customer     = customer.
    me->credit_limit = credit_limit.
    me->open_amount  = open_amount.
    me->order_amount = order_amount.
    me->currency     = currency.
  ENDMETHOD.

  METHOD if_message~get_text.
    " RAP 메시지(new_message_with_text)는 50자에서 잘리므로 짧게
    result = |한도초과: 한도 { credit_limit CURRENCY = currency } / 기승인 { open_amount CURRENCY = currency }| &&
             | / 이번 { order_amount CURRENCY = currency } { currency }|.
  ENDMETHOD.
ENDCLASS.
