"! 신용한도 관련 예외의 묶음용 부모 - 직접 RAISE 할 수 없음(ABSTRACT)
CLASS zcx_cih_credit DEFINITION PUBLIC INHERITING FROM cx_static_check ABSTRACT CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor IMPORTING previous LIKE previous OPTIONAL.
ENDCLASS.

CLASS zcx_cih_credit IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
  ENDMETHOD.
ENDCLASS.
