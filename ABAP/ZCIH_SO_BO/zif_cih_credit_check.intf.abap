"! 신용한도 체크 - 쓰는 쪽(RAP, 배치, 리포트)은 이 인터페이스만 안다
INTERFACE zif_cih_credit_check PUBLIC.
  TYPES ty_customer TYPE c LENGTH 10.
  TYPES ty_amount   TYPE p LENGTH 8 DECIMALS 2.   " abap.curr(15,2) 와 같은 기술 타입
  TYPES ty_currency TYPE c LENGTH 5.

  "! 한도를 넘으면 zcx_cih_credit_exceeded, 한도 미등록 고객이면 zcx_cih_customer_unknown
  METHODS check
    IMPORTING iv_customer TYPE ty_customer
              iv_amount   TYPE ty_amount
              iv_currency TYPE ty_currency
    RAISING   zcx_cih_credit.
ENDINTERFACE.
