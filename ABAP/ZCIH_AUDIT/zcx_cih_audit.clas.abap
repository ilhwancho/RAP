"! <p class="shorttext synchronized">감사필드 헬퍼 오류</p>
"! 감사필드가 없는 테이블, 지원하지 않는 필드 타입 등 (대부분 개발 오류).
CLASS zcx_cih_audit DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    DATA mv_text TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING iv_text  TYPE string OPTIONAL
                previous LIKE previous OPTIONAL.

    METHODS if_message~get_text REDEFINITION.
ENDCLASS.


CLASS zcx_cih_audit IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD if_message~get_text.
    result = mv_text.
  ENDMETHOD.

ENDCLASS.
