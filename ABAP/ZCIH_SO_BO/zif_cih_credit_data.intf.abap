"! 신용한도 체크에 필요한 데이터 조회 - DB 를 직접 보지 않게 떼어낸 부분
INTERFACE zif_cih_credit_data PUBLIC.
  METHODS get_limit
    IMPORTING iv_customer     TYPE zif_cih_credit_check=>ty_customer
    RETURNING VALUE(rv_limit) TYPE zif_cih_credit_check=>ty_amount
    RAISING   zcx_cih_customer_unknown.

  "! 이미 승인(A)된 오더 금액 합계
  METHODS get_open_amount
    IMPORTING iv_customer    TYPE zif_cih_credit_check=>ty_customer
    RETURNING VALUE(rv_open) TYPE zif_cih_credit_check=>ty_amount.
ENDINTERFACE.
